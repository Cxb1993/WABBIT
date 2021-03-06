!> \file
! WABBIT
!> \name keyvalues.f90
!> \version 0.5
!> \author sm, engels
!
!> \brief loads the specified *.h5 file and creates a *.key file that contains
!! min / max / mean / L2 norm of the field data. This is used for testing
!! so that we don't need to store entire fields but rather the *.key only
!! \version 10/1/18 - create commit b2719e1aa2339f4f1f83fb29bd2e4e5e81d05a2a
!*********************************************************************************************

subroutine post_mean(params, help)

  use module_IO
  use module_precision
  use module_params
  use module_mesh
  use mpi

  implicit none
  !> name of the file
  character(len=80)            :: fname
  !> parameter struct
  type (type_params), intent(inout)       :: params
  !> help flag
  logical, intent(in)                     :: help
  integer(kind=ik), allocatable           :: lgt_block(:, :)
  real(kind=rk), allocatable              :: hvy_block(:, :, :, :, :)
  integer(kind=ik), allocatable           :: hvy_neighbor(:,:)
  integer(kind=ik), allocatable           :: lgt_active(:), hvy_active(:)
  integer(kind=tsize), allocatable        :: lgt_sortednumlist(:,:)
  integer(hsize_t), dimension(4)          :: size_field
  integer(hid_t)                          :: file_id
  integer(kind=ik)                        :: lgt_id, k, Bs, nz, iteration, lgt_n, hvy_n, dim
  real(kind=rk), dimension(3)             :: x0, dx
  real(kind=rk), dimension(3)             :: domain
  real(kind=rk)                           :: time
  integer(hsize_t), dimension(2)          :: dims_treecode
  integer(kind=ik), allocatable           :: tree(:), sum_tree(:), blocks_per_rank(:)


  real(kind=rk)    :: x,y,z
  real(kind=rk)    :: maxi,mini,squari,meani,qi
  real(kind=rk)    :: maxl,minl,squarl,meanl,ql
  integer(kind=ik) :: ix,iy,iz,mpicode, ioerr, rank, i, g, tc_length



  !-----------------------------------------------------------------------------------------------------
  rank = params%rank
  !-----------------------------------------------------------------------------------------------------
  if (help) then
    if (rank==0) then
      write(*,*) "WABBIT postprocessing "
      write(*,*) "mpi_command -n number_procs ./wabbit-post 2[3]D --mean filename.h5"
    end if
    return
  endif

  call get_command_argument(3,fname)
  write (*,*) "Computing spatial mean of file: "//trim(adjustl(fname))
  call check_file_exists( fname )

  ! et some parameters from the file
  call read_attributes(fname, lgt_n, time, iteration, domain, Bs, tc_length, dim)

  params%number_block_nodes = Bs
  params%number_data_fields = 1
  params%number_ghost_nodes = 0
  g = 0
  params%max_treelevel = tc_length
  params%Lx = domain(1)
  params%Ly = domain(2)
  params%Lz = domain(3)
  params%number_blocks = 2_ik*lgt_n/params%number_procs

  call allocate_grid(params, lgt_block, hvy_block, hvy_neighbor, lgt_active,&
      hvy_active, lgt_sortednumlist, .false.)

  call read_mesh(fname, params, lgt_n, hvy_n, lgt_block)
  call read_field(fname, 1, params, hvy_block, hvy_n )

  call create_active_and_sorted_lists( params, lgt_block, &
  lgt_active, lgt_n, hvy_active, hvy_n, lgt_sortednumlist, .true. )

  call update_neighbors( params, lgt_block, hvy_neighbor, lgt_active, &
  lgt_n, lgt_sortednumlist, hvy_active, hvy_n )

  ! compute an additional quantity that depends also on the position
  ! (the others are translation invariant)
  if (params%threeD_case) then
    nz = Bs
  else
    nz = 1
  end if


  meanl = 0.0_rk

  do k = 1,hvy_n
    call hvy_id_to_lgt_id(lgt_id, hvy_active(k), params%rank, params%number_blocks)
    call get_block_spacing_origin( params, lgt_id, lgt_block, x0, dx )

    if (params%threeD_case) then
      meanl = meanl + sum( hvy_block(g+1:Bs+g, g+1:Bs+g, g+1:Bs+g, 1, hvy_active(k)))*dx(1)*dx(2)*dx(3)
    else
      meanl = meanl + sum( hvy_block(g+1:Bs+g, g+1:Bs+g, 1, 1, hvy_active(k)))*dx(1)*dx(2)
    endif
  end do

  call MPI_REDUCE(meanl,meani,1,MPI_DOUBLE_PRECISION,MPI_SUM,0,WABBIT_COMM,mpicode)

  if (params%threeD_case) then
    meani = meani / (params%Lx*params%Ly*params%Lz)
  else
    meani = meani / (params%Lx*params%Ly)
  endif

  if (rank == 0) then
    write(*,*) "Computed mean value is: ", meani
  endif
end subroutine post_mean
