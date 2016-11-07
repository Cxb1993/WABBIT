! ********************************
! WABBIT
! --------------------------------
!
! write data of a single 2D field phi
! at timestep n and time t
!
! name: write_field.f90
! date: 25.10.2016
! author: engels, msr
! version: 0.3
!
! ********************************

subroutine write_field(iteration, time, dF, fname)

    use mpi
    use module_params
    use module_blocks
    use hdf5_wrapper

    implicit none

    real(kind=rk), intent(in) 	                :: time
    integer(kind=ik), intent(in)                :: iteration, dF

    character(len=80), intent(inout)            :: fname

    character(len=80)                           :: dsetname
    integer(kind=ik)                            :: k, g, Bs, rank, ierr, allocate_error, heavy_id, tag
    integer                                     :: status(MPI_status_size)

    real(kind=rk), dimension(:,:), allocatable  :: data_
    real(kind=rk), dimension(:), allocatable    :: coord_
    real(kind=rk)                               :: detail_

    call MPI_Comm_rank(MPI_COMM_WORLD, rank, ierr)

    tag = 0

    Bs  = blocks_params%size_block
    g   = blocks_params%number_ghost_nodes

    ! allocate data fields for data exchange
    allocate( data_(1:Bs, 1:Bs), stat=allocate_error )
    allocate( coord_(1:Bs), stat=allocate_error )

    write( fname,'("data_",i8.8,".h5")') nint(time * 1.0e4_rk)

    ! create the filename
    if ( (rank == 0) .and. (dF == 1) ) then
        write(*,'(80("*"))')
        write(*,'("Writing data... time=",f15.8," fname=",A)') time, trim(adjustl(fname))
        write(*,'(80("*"))')
        ! overwrite the file, if it already exists
        call init_empty_file( fname )
    end if

    ! save block data
    do k = 1, blocks_params%number_max_blocks
        if (blocks(k)%active .and. blocks(k)%proc_rank == rank ) then
                ! the name of the block within th hdf5 file
                write(dsetname,'("block_",i8.8, "_field_",i2.2)') k, dF

                heavy_id = blocks(k)%proc_data_id
                call write_field_hdf5( fname, dsetname, blocks_data(heavy_id)%data_fields(dF)%data_(g+1:Bs+g,g+1:Bs+g), .false.)

                ! save data field number
                call write_attribute( fname, dsetname, "data field", (/dF/))

                ! add useful attributes to the block:
                call write_attribute( fname, dsetname, "treecode", blocks(k)%treecode)
                call write_attribute( fname, dsetname, "time", (/time/))
                call write_attribute( fname, dsetname, "iteration", (/iteration/))

                ! heavy data exchange
                ! if data on proc 0: write data
                ! else: receive data from proc with block data
                call write_attribute( fname, dsetname, "coord_x", blocks_data(heavy_id)%coord_x)
                call write_attribute( fname, dsetname, "coord_y", blocks_data(heavy_id)%coord_y)

                call write_attribute( fname, dsetname, "neighbor-id1", (/blocks(k)%neighbor_id(1)/) )
                call write_attribute( fname, dsetname, "neighbor-treecode1", blocks(k)%neighbor_treecode(1,:))

                call write_attribute( fname, dsetname, "neighbor-id2", (/blocks(k)%neighbor_id(2)/) )
                call write_attribute( fname, dsetname, "neighbor-treecode2", blocks(k)%neighbor_treecode(2,:))

                call write_attribute( fname, dsetname, "neighbor-id3", (/blocks(k)%neighbor_id(3)/) )
                call write_attribute( fname, dsetname, "neighbor-treecode3", blocks(k)%neighbor_treecode(3,:))

                call write_attribute( fname, dsetname, "neighbor-id4", (/blocks(k)%neighbor_id(4)/) )
                call write_attribute( fname, dsetname, "neighbor-treecode4", blocks(k)%neighbor_treecode(4,:))

                call write_attribute( fname, dsetname, "neighbor-id5", (/blocks(k)%neighbor_id(5)/) )
                call write_attribute( fname, dsetname, "neighbor-treecode5", blocks(k)%neighbor_treecode(5,:))

                call write_attribute( fname, dsetname, "neighbor-id6", (/blocks(k)%neighbor_id(6)/) )
                call write_attribute( fname, dsetname, "neighbor-treecode6", blocks(k)%neighbor_treecode(6,:))

                call write_attribute( fname, dsetname, "neighbor-id7", (/blocks(k)%neighbor_id(7)/) )
                call write_attribute( fname, dsetname, "neighbor-treecode7", blocks(k)%neighbor_treecode(7,:))

                call write_attribute( fname, dsetname, "neighbor-id8", (/blocks(k)%neighbor_id(8)/) )
                call write_attribute( fname, dsetname, "neighbor-treecode8", blocks(k)%neighbor_treecode(8,:))

                call write_attribute( fname, dsetname, "neighbor-id9", (/blocks(k)%neighbor_id(9)/) )
                call write_attribute( fname, dsetname, "neighbor-treecode9", blocks(k)%neighbor_treecode(9,:))

                call write_attribute( fname, dsetname, "neighbor-id10", (/blocks(k)%neighbor_id(10)/) )
                call write_attribute( fname, dsetname, "neighbor-treecode10", blocks(k)%neighbor_treecode(10,:))

                call write_attribute( fname, dsetname, "neighbor-id11", (/blocks(k)%neighbor_id(11)/) )
                call write_attribute( fname, dsetname, "neighbor-treecode11", blocks(k)%neighbor_treecode(11,:))

                call write_attribute( fname, dsetname, "neighbor-id12", (/blocks(k)%neighbor_id(12)/) )
                call write_attribute( fname, dsetname, "neighbor-treecode12", blocks(k)%neighbor_treecode(12,:))

                call write_attribute( fname, dsetname, "neighbor-id13", (/blocks(k)%neighbor_id(13)/) )
                call write_attribute( fname, dsetname, "neighbor-treecode13", blocks(k)%neighbor_treecode(13,:))

                call write_attribute( fname, dsetname, "neighbor-id14", (/blocks(k)%neighbor_id(14)/) )
                call write_attribute( fname, dsetname, "neighbor-treecode14", blocks(k)%neighbor_treecode(14,:))

                call write_attribute( fname, dsetname, "neighbor-id15", (/blocks(k)%neighbor_id(15)/) )
                call write_attribute( fname, dsetname, "neighbor-treecode15", blocks(k)%neighbor_treecode(15,:))

                call write_attribute( fname, dsetname, "neighbor-id16", (/blocks(k)%neighbor_id(16)/) )
                call write_attribute( fname, dsetname, "neighbor-treecode16", blocks(k)%neighbor_treecode(16,:))

                call write_attribute( fname, dsetname, "detail", (/blocks_data(heavy_id)%data_fields(dF)%detail/))

        end if

        call MPI_BARRIER(MPI_COMM_WORLD,ierr)
    end do

    stop


    ! deallocate data fields
    deallocate( data_, stat=allocate_error )
    deallocate( coord_, stat=allocate_error )

end subroutine write_field
