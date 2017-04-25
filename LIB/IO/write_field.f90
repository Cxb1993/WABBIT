!> \file
!> \callgraph
! ********************************************************************************************
! WABBIT
! ============================================================================================
!> \name write_field.f90
!> \version 0.5
!> \author engels, msr
!
!> \brief write data of a single datafield dF at timestep iteration and time t
!
!> \details
!! input:    
!!           - time loop parameter
!!           - datafield number
!!           - parameter array
!!           - light data array
!!           - heavy data array
!!
!! output:   -
!! \n
!! = log ======================================================================================
!! \n
!! 07/11/16 
!!          - switch to v0.4
!!
!! 26/01/17 
!!          - switch to 3D, v0.5
!!          - add dirs_3D array for 3D neighbor codes
!!
!! 21/02/17 
!!          - use parallel IO, write one data array with all data
!
! ********************************************************************************************
subroutine write_field( fname, time, iteration, dF, params, hvy_block, lgt_active, lgt_n, hvy_n)

!---------------------------------------------------------------------------------------------
! modules

    use hdf5
    use module_mpi

!---------------------------------------------------------------------------------------------
! variables

    implicit none

    !> file name
    character(len=*), intent(in)        :: fname

    !> time loop parameters
    real(kind=rk), intent(in)           :: time
    integer(kind=ik), intent(in)        :: iteration

    !> datafield number
    integer(kind=ik), intent(in)        :: dF

    !> user defined parameter structure
    type (type_params), intent(in)      :: params
    !> heavy data array - block data
    real(kind=rk), intent(in)           :: hvy_block(:, :, :, :, :)

    !> list of active blocks (light data)
    integer(kind=ik), intent(in)        :: lgt_active(:)
    !> number of active blocks (light data)
    integer(kind=ik), intent(in)        :: lgt_n
    ! number of active blocks (heavy data)
    integer(kind=ik)                    :: hvy_n

    ! process rank
    integer(kind=ik)                    :: rank, lgt_rank
    ! loop variable
    integer(kind=ik)                    :: k, hvy_id, l
    ! grid parameter
    integer(kind=ik)                    :: Bs, g

    ! block data buffer, need for compact data storage
    real(kind=rk), allocatable          :: myblockbuffer(:,:,:,:)
    ! coordinates and spacing arrays
    real(kind=rk), allocatable          :: coords_origin(:,:), coords_spacing(:,:)

    ! file id integer
    integer(hid_t)                      :: file_id

    ! offset variables
    integer,dimension(1:4)              :: ubounds3D, lbounds3D
    integer,dimension(1:3)              :: ubounds2D, lbounds2D

    ! procs per rank array
    integer, dimension(:), allocatable  :: actual_blocks_per_proc

    ! allocation error variable
    integer(kind=ik)                    :: allocate_error

!---------------------------------------------------------------------------------------------
! variables initialization

    ! set MPI parameters
    rank = params%rank

    ! grid parameter
    Bs   = params%number_block_nodes
    g    = params%number_ghost_nodes

    ! to know our position in the last index of the 4D output array, we need to
    ! know how many blocks all procs have
    allocate(actual_blocks_per_proc( 0:params%number_procs-1 ), stat=allocate_error)
    !call check_allocation(allocate_error)
    if ( allocate_error /= 0 ) then
        write(*,'(80("_"))')
        write(*,*) "ERROR: memory allocation fails"
        stop
    end if

    allocate (myblockbuffer( 1:Bs, 1:Bs, 1:Bs, 1:hvy_n ), stat=allocate_error)
    !call check_allocation(allocate_error)
    if ( allocate_error /= 0 ) then
        write(*,'(80("_"))')
        write(*,*) "ERROR: memory allocation fails"
        stop
    end if

    allocate (coords_spacing(1:3, 1:hvy_n), stat=allocate_error)
    !call check_allocation(allocate_error)
    if ( allocate_error /= 0 ) then
        write(*,'(80("_"))')
        write(*,*) "ERROR: memory allocation fails"
        stop
    end if

    allocate (coords_origin(1:3, 1:hvy_n), stat=allocate_error)
    !call check_allocation(allocate_error)
    if ( allocate_error /= 0 ) then
        write(*,'(80("_"))')
        write(*,*) "ERROR: memory allocation fails"
        stop
    end if

!---------------------------------------------------------------------------------------------
! main body

    ! output on screen
    if (rank == 0) then
        write(*,'(80("_"))')
        write(*,'("IO: writing data for time = ", f15.8," file = ",A," active blocks=",i5)') time, trim(adjustl(fname)), lgt_n
    endif

    call blocks_per_mpirank( params, actual_blocks_per_proc, hvy_n )

    ! fill blocks buffer (we cannot use the bvy_block array as it is not contiguous, i.e.
    ! it may contain holes)
    if ( params%threeD_case ) then

        ! tell the hdf5 wrapper what part of the global [bs x bs x bs x n_active]
        ! array we hold, so that all CPU can write to the same file simultaneously
        ! (note zero-based offset):
        lbounds3D = (/1,1,1,sum(actual_blocks_per_proc(0:rank-1))+1/) - 1
        ubounds3D = (/Bs-1,Bs-1,Bs-1,lbounds3D(4)+hvy_n-1/)

    else

        ! tell the hdf5 wrapper what part of the global [bs x bs x bs x n_active]
        ! array we hold, so that all CPU can write to the same file simultaneously
        ! (note zero-based offset):
        lbounds2D = (/1,1,sum(actual_blocks_per_proc(0:rank-1))+1/) - 1
        ubounds2D = (/Bs-1,Bs-1,lbounds2D(3)+hvy_n-1/)

    endif

    l = 1
    ! loop over all active light block IDs, check if it is mine, if so, copy the block to the buffer
    do k = 1, lgt_n

        ! calculate proc rank from light data line number
        call lgt_id_to_proc_rank( lgt_rank, lgt_active(k), params%number_blocks )
        ! calculate heavy block id corresponding to light id
        call lgt_id_to_hvy_id( hvy_id, lgt_active(k), rank, params%number_blocks )

        ! if I own this block, I copy it to the buffer.
        ! also extract block coordinate origin and spacing
        if (lgt_rank == rank) then
            if ( params%threeD_case ) then
                ! 3D
                myblockbuffer(:,:,:,l)      = hvy_block( g+1:Bs+g, g+1:Bs+g, g+1:Bs+g, dF, hvy_id)
                coords_origin(1:3,l)        = hvy_block( 1:3, 1, 1, 1, hvy_id)
                coords_spacing(1:3,l)       = abs(hvy_block( 1:3, 2, 1, 1, hvy_id) - hvy_block( 1:3, 1, 1, 1, hvy_id) )
            else
                ! 2D
                myblockbuffer(:,:,1,l)      = hvy_block( g+1:Bs+g, g+1:Bs+g, 1, dF, hvy_id)
                coords_origin(1:2,l)        = hvy_block( 1:2, 1, 1, 1, hvy_id)
                coords_spacing(1:2,l)       = abs(hvy_block( 1:2, 2, 1, 1, hvy_id) - hvy_block( 1:2, 1, 1, 1, hvy_id) )
            endif

            ! next block
            l = l + 1
        endif

    end do

    ! open the file
    call open_file_hdf5( trim(adjustl(fname)), file_id, .true.)

    ! write heavy block data to disk
    if ( params%threeD_case ) then
        ! 3D data case
        call write_dset_mpi_hdf5_4D(file_id, "blocks", lbounds3D, ubounds3D, myblockbuffer)
        call write_attribute(file_id, "blocks", "domain-size", (/params%Lx, params%Ly, params%Lz/))
        call write_dset_mpi_hdf5_2D(file_id, "coords_origin", (/0,lbounds3D(4)/), (/2,ubounds3D(4)/), coords_origin)
        call write_dset_mpi_hdf5_2D(file_id, "coords_spacing", (/0,lbounds3D(4)/), (/2,ubounds3D(4)/), coords_spacing)
    else
        ! 2D data case
        call write_dset_mpi_hdf5_3D(file_id, "blocks", lbounds2D, ubounds2D, myblockbuffer(:,:,1,:))
        call write_attribute(file_id, "blocks", "domain-size", (/params%Lx, params%Ly/))
        call write_dset_mpi_hdf5_2D(file_id, "coords_origin", (/0,lbounds2D(3)/), (/1,ubounds2D(3)/), coords_origin(1:2,:))
        call write_dset_mpi_hdf5_2D(file_id, "coords_spacing", (/0,lbounds2D(3)/), (/1,ubounds2D(3)/), coords_spacing(1:2,:))
    endif

    ! add aditional annotations
    call write_attribute(file_id, "blocks", "time", (/time/))
    call write_attribute(file_id, "blocks", "iteration", (/iteration/))

    ! close file and HDF5 library
    call close_file_hdf5(file_id)

    ! clean up
    deallocate(actual_blocks_per_proc, stat=allocate_error)
    deallocate(myblockbuffer, stat=allocate_error)
    deallocate(coords_origin, stat=allocate_error)
    deallocate(coords_spacing, stat=allocate_error)

end subroutine write_field
