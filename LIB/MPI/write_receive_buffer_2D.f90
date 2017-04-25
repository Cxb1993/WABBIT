!> \file
!> \callgraph
! ********************************************************************************************
! WABBIT
! ============================================================================================
!> \name write_receive_buffer_2D.f90
!> \version 0.4
!> \author msr
!
!> \brief write received buffer to heavy data with integer and real buffer
!
!> \details
!! input:    
!!           - params struct
!!           - received buffer
!!
!! output:   
!!           - heavy data array
!!
!! \n
! -------------------------------------------------------------------------------------------------------------------------
!> dirs = (/'__N', '__E', '__S', '__W', '_NE', '_NW', '_SE', '_SW', 'NNE', 'NNW', 'SSE', 'SSW', 'ENE', 'ESE', 'WNW', 'WSW'/) \n
! -------------------------------------------------------------------------------------------------------------------------
!
!> = log ======================================================================================
!! \n
!! 09/01/17 - create for v0.4
! ********************************************************************************************

subroutine write_receive_buffer_2D(params, int_buffer, recv_buff, hvy_block)

!---------------------------------------------------------------------------------------------
! modules

!---------------------------------------------------------------------------------------------
! variables

    implicit none

    !> user defined parameter structure
    type (type_params), intent(in)                  :: params
    !> send buffer
    integer(kind=ik), intent(in)                    :: int_buffer(:)
    !> send buffer
    real(kind=rk), intent(in)                       :: recv_buff(:)

    !> heavy data array - block data
    real(kind=rk), intent(inout)                    :: hvy_block(:, :, :, :)

    ! buffer index
    integer(kind=ik)                                :: buffer_i

    ! grid parameter
    integer(kind=ik)                                :: Bs, g

    ! interpolation variables
    real(kind=rk), dimension(:,:), allocatable      :: data_corner, data_corner_fine, data_edge, data_edge_fine

    ! allocation error variable
    integer(kind=ik)                                :: allocate_error

    ! com list elements
    integer(kind=ik)                                :: my_block, my_dir, level_diff

    ! loop variable
    integer(kind=ik)                                :: k, l, dF

!---------------------------------------------------------------------------------------------
! interfaces

!---------------------------------------------------------------------------------------------
! variables initialization

    ! grid parameter
    Bs    = params%number_block_nodes
    g     = params%number_ghost_nodes

    allocate( data_corner( g, g), stat=allocate_error )
    if ( allocate_error /= 0 ) then
        write(*,'(80("_"))')
        write(*,*) "ERROR: memory allocation fails"
        stop
    end if

    allocate( data_corner_fine( 2*g-1, 2*g-1), stat=allocate_error )
    if ( allocate_error /= 0 ) then
        write(*,'(80("_"))')
        write(*,*) "ERROR: memory allocation fails"
        stop
    end if

    allocate( data_edge( (Bs+1)/2 + g/2, (Bs+1)/2 + g/2), stat=allocate_error )
    if ( allocate_error /= 0 ) then
        write(*,'(80("_"))')
        write(*,*) "ERROR: memory allocation fails"
        stop
    end if

    allocate( data_edge_fine( Bs+g, Bs+g), stat=allocate_error )
    if ( allocate_error /= 0 ) then
        write(*,'(80("_"))')
        write(*,*) "ERROR: memory allocation fails"
        stop
    end if

    buffer_i         = 1

    data_corner      = 9.0e9_rk
    data_corner_fine = 9.0e9_rk
    data_edge        = 9.0e9_rk
    data_edge_fine   = 9.0e9_rk

!---------------------------------------------------------------------------------------------
! main body

    ! write received data in block data
    do k = 1, size(int_buffer,1), 3

        my_block        = int_buffer( k )
        my_dir          = int_buffer( k+1 )
        level_diff      = int_buffer( k+2 )

        select case(my_dir)
            ! '__N'
            case(1)
                do dF = 2, params%number_data_fields+1
                    do l = 1, g
                        hvy_block( Bs+g+l, g+1:Bs+g, dF, my_block )     = recv_buff(buffer_i:buffer_i+Bs-1)
                        buffer_i                                         = buffer_i + Bs
                    end do
                end do

            ! '__E'
            case(2)
                do dF = 2, params%number_data_fields+1
                    do l = 1, g
                        hvy_block( g+1:Bs+g, g+1-l, dF , my_block)      = recv_buff(buffer_i:buffer_i+Bs-1)
                        buffer_i                                         = buffer_i + Bs
                    end do
                end do

            ! '__S'
            case(3)
                do dF = 2, params%number_data_fields+1
                    do l = 1, g
                        hvy_block( g+1-l, g+1:Bs+g, dF, my_block )      = recv_buff(buffer_i:buffer_i+Bs-1)
                        buffer_i                                         = buffer_i + Bs
                    end do
                end do

            ! '__W'
            case(4)
                do dF = 2, params%number_data_fields+1
                    do l = 1, g
                        hvy_block( g+1:Bs+g, Bs+g+l, dF, my_block )     = recv_buff(buffer_i:buffer_i+Bs-1)
                        buffer_i                                         = buffer_i + Bs
                    end do
                end do

            ! '_NE'
            case(5)
                do dF = 2, params%number_data_fields+1
                    ! receive data
                    do l = 1, g
                        data_corner(l, 1:g) = recv_buff(buffer_i:buffer_i+g-1)
                        buffer_i            = buffer_i + g
                    end do
                    ! write data
                    hvy_block( Bs+g+1:Bs+g+g, 1:g, dF, my_block ) = data_corner
                end do

            ! '_NW'
            case(6)
                do dF = 2, params%number_data_fields+1
                    ! receive data
                    do l = 1, g
                        data_corner(l, 1:g) = recv_buff(buffer_i:buffer_i+g-1)
                        buffer_i            = buffer_i + g
                    end do
                    ! write data
                    hvy_block( Bs+g+1:Bs+g+g, Bs+g+1:Bs+g+g, dF, my_block ) = data_corner
                end do

            ! '_SE'
            case(7)
                do dF = 2, params%number_data_fields+1
                    ! receive data
                    do l = 1, g
                        data_corner(l, 1:g) = recv_buff(buffer_i:buffer_i+g-1)
                        buffer_i            = buffer_i + g
                    end do
                    ! write data
                    hvy_block( 1:g, 1:g, dF, my_block ) = data_corner
                end do

            ! '_SW'
            case(8)
                do dF = 2, params%number_data_fields+1
                    ! receive data
                    do l = 1, g
                        data_corner(l, 1:g) = recv_buff(buffer_i:buffer_i+g-1)
                        buffer_i            = buffer_i + g
                    end do
                    ! write data
                    hvy_block( 1:g, Bs+g+1:Bs+g+g, dF, my_block ) = data_corner
                end do

            ! 'NNE'
            case(9)
                do dF = 2, params%number_data_fields+1
                    if ( level_diff == -1 ) then
                        ! sender on lower level
                        ! receive data
                        do l = 1, g
                            data_edge_fine(l, 1:Bs+g)         = recv_buff(buffer_i:buffer_i+Bs+g-1)
                            buffer_i                          = buffer_i + Bs+g
                        end do

                        ! write data
                        hvy_block( Bs+g+1:Bs+g+g, 1:Bs+g, dF, my_block ) = data_edge_fine(1:g, 1:Bs+g)

                    elseif ( level_diff == 1 ) then
                        ! sender on higher level
                        ! receive data
                        do l = 1, g
                            hvy_block( Bs+g+l, g+(Bs+1)/2:Bs+g, dF, my_block )  = recv_buff(buffer_i:buffer_i+(Bs+1)/2-1)
                            buffer_i                                             = buffer_i + (Bs+1)/2
                        end do

                    else
                        ! error case
                        write(*,'(80("_"))')
                        write(*,*) "ERROR: can not synchronize ghost nodes, mesh is not graded"
                        stop
                    end if
                end do

            ! 'NNW'
            case(10)
                do dF = 2, params%number_data_fields+1
                    if ( level_diff == -1 ) then
                        ! sender on lower level
                        ! receive data
                        do l = 1, g
                            data_edge_fine(l, 1:Bs+g)         = recv_buff(buffer_i:buffer_i+Bs+g-1)
                            buffer_i                          = buffer_i + Bs+g
                        end do
                        ! write data
                        hvy_block( Bs+g+1:Bs+g+g, g+1:Bs+2*g, dF, my_block ) = data_edge_fine(1:g, 1:Bs+g)

                    elseif ( level_diff == 1 ) then
                        ! sender on higher level
                        ! receive data
                        do l = 1, g
                            hvy_block( Bs+g+l, g+1:g+(Bs+1)/2, dF, my_block )  = recv_buff(buffer_i:buffer_i+(Bs+1)/2-1)
                            buffer_i                                            = buffer_i + (Bs+1)/2
                        end do

                    else
                        ! error case
                        write(*,'(80("_"))')
                        write(*,*) "ERROR: can not synchronize ghost nodes, mesh is not graded"
                        stop
                    end if
                end do

            ! 'SSE'
            case(11)
                do dF = 2, params%number_data_fields+1
                    if ( level_diff == -1 ) then
                        ! sender on lower level
                        ! receive data
                        do l = 1, g
                            data_edge_fine(g-l+1, 1:Bs+g)     = recv_buff(buffer_i:buffer_i+Bs+g-1)
                            buffer_i                          = buffer_i + Bs+g
                        end do
                        ! write data
                        hvy_block( 1:g, 1:Bs+g, dF, my_block ) = data_edge_fine(1:g, 1:Bs+g)

                    elseif ( level_diff == 1 ) then
                        ! sender on higher level
                        ! receive data
                        do l = 1, g
                            hvy_block( g-l+1, g+(Bs+1)/2:Bs+g, dF, my_block )  = recv_buff(buffer_i:buffer_i+(Bs+1)/2-1)
                            buffer_i                                            = buffer_i + (Bs+1)/2
                        end do

                    else
                        ! error case
                        write(*,'(80("_"))')
                        write(*,*) "ERROR: can not synchronize ghost nodes, mesh is not graded"
                        stop
                    end if
                end do

            ! 'SSW'
            case(12)
                do dF = 2, params%number_data_fields+1
                    if ( level_diff == -1 ) then
                        ! sender on lower level
                        ! receive data
                        do l = 1, g
                            data_edge_fine(g-l+1, 1:Bs+g)     = recv_buff(buffer_i:buffer_i+Bs+g-1)
                            buffer_i                          = buffer_i + Bs+g
                        end do
                        ! write data
                        hvy_block( 1:g, g+1:Bs+2*g, dF, my_block ) = data_edge_fine(1:g, 1:Bs+g)

                    elseif ( level_diff == 1 ) then
                        ! sender on higher level
                        ! receive data
                        do l = 1, g
                            hvy_block( g-l+1, g+1:g+(Bs+1)/2, dF, my_block )  = recv_buff(buffer_i:buffer_i+(Bs+1)/2-1)
                            buffer_i                                           = buffer_i + (Bs+1)/2
                        end do

                    else
                        ! error case
                        write(*,'(80("_"))')
                        write(*,*) "ERROR: can not synchronize ghost nodes, mesh is not graded"
                        stop
                    end if
                end do

            ! 'ENE'
            case(13)
                do dF = 2, params%number_data_fields+1
                    if ( level_diff == -1 ) then
                        ! sender on lower level
                        ! receive data
                        do l = 1, g
                            data_edge_fine(1:Bs+g, Bs+l)     = recv_buff(buffer_i:buffer_i+Bs+g-1)
                            buffer_i                         = buffer_i + Bs+g
                        end do
                        ! write data
                        hvy_block( g+1:Bs+2*g, 1:g, dF, my_block ) = data_edge_fine(1:Bs+g, Bs+1:Bs+g)

                    elseif ( level_diff == 1 ) then
                        ! sender on higher level
                        ! receive data
                        do l = 1, g
                            hvy_block( g+1:g+(Bs+1)/2, l, dF, my_block )  = recv_buff(buffer_i:buffer_i+(Bs+1)/2-1)
                            buffer_i                                       = buffer_i + (Bs+1)/2
                        end do

                    else
                        ! error case
                        write(*,'(80("_"))')
                        write(*,*) "ERROR: can not synchronize ghost nodes, mesh is not graded"
                        stop
                    end if
                end do

            ! 'ESE'
            case(14)
                do dF = 2, params%number_data_fields+1
                    if ( level_diff == -1 ) then
                        ! sender on lower level
                        ! receive data
                        do l = 1, g
                            data_edge_fine(1:Bs+g, Bs+l)     = recv_buff(buffer_i:buffer_i+Bs+g-1)
                            buffer_i                          = buffer_i + Bs+g
                        end do
                        ! write data
                        hvy_block( 1:Bs+g, 1:g, dF, my_block ) = data_edge_fine(1:Bs+g, Bs+1:Bs+g)

                    elseif ( level_diff == 1 ) then
                        ! sender on higher level
                        ! receive data
                        do l = 1, g
                            hvy_block( g+(Bs+1)/2:Bs+g, l, dF, my_block )  = recv_buff(buffer_i:buffer_i+(Bs+1)/2-1)
                            buffer_i                                        = buffer_i + (Bs+1)/2
                        end do

                    else
                        ! error case
                        write(*,'(80("_"))')
                        write(*,*) "ERROR: can not synchronize ghost nodes, mesh is not graded"
                        stop
                    end if
                end do

            ! 'WNW'
            case(15)
                do dF = 2, params%number_data_fields+1
                    if ( level_diff == -1 ) then
                        ! sender on lower level
                        ! receive data
                        do l = 1, g
                            data_edge_fine(1:Bs+g, l)     = recv_buff(buffer_i:buffer_i+Bs+g-1)
                            buffer_i                      = buffer_i + Bs+g
                        end do
                        ! write data
                        hvy_block( g+1:Bs+2*g, Bs+g+1:Bs+g+g, dF, my_block ) = data_edge_fine(1:Bs+g, 1:g)

                    elseif ( level_diff == 1 ) then
                        ! sender on higher level
                        ! receive data
                        do l = 1, g
                            hvy_block( g+1:g+(Bs+1)/2, Bs+g+l, dF, my_block )  = recv_buff(buffer_i:buffer_i+(Bs+1)/2-1)
                            buffer_i                                            = buffer_i + (Bs+1)/2
                        end do

                    else
                        ! error case
                        write(*,'(80("_"))')
                        write(*,*) "ERROR: can not synchronize ghost nodes, mesh is not graded"
                        stop
                    end if
                end do

            ! 'WSW'
            case(16)
                do dF = 2, params%number_data_fields+1
                    if ( level_diff == -1 ) then
                        ! sender on lower level
                        ! receive data
                        do l = 1, g
                            data_edge_fine(1:Bs+g, l)     = recv_buff(buffer_i:buffer_i+Bs+g-1)
                            buffer_i                      = buffer_i + Bs+g
                        end do
                        ! write data
                        hvy_block( 1:Bs+g, Bs+g+1:Bs+g+g, dF, my_block ) = data_edge_fine(1:Bs+g, 1:g)

                    elseif ( level_diff == 1 ) then
                        ! sender on higher level
                        ! receive data
                        do l = 1, g
                            hvy_block( g+(Bs+1)/2:Bs+g, Bs+g+l, dF, my_block )  = recv_buff(buffer_i:buffer_i+(Bs+1)/2-1)
                            buffer_i                                             = buffer_i + (Bs+1)/2
                        end do

                    else
                        ! error case
                        write(*,'(80("_"))')
                        write(*,*) "ERROR: can not synchronize ghost nodes, mesh is not graded"
                        stop
                    end if
                end do

        end select

    end do

    ! clean up
    deallocate( data_corner, stat=allocate_error )
    deallocate( data_corner_fine, stat=allocate_error )
    deallocate( data_edge, stat=allocate_error )
    deallocate( data_edge_fine, stat=allocate_error )

end subroutine write_receive_buffer_2D
