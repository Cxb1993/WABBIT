!> \file
!> \callgraph
! ********************************************************************************************
! WABBIT
! ============================================================================================
!> \name ensure_gradedness.f90
!> \version 0.5
!> \author msr, engels
!
!> \brief check the gradedness after new refinement status
!
!> \details This routine is called after all blocks have been tagged whether to refine or coarsen or stay.
!! It now goes through the list of blocks and looks for refinement or coarsening states that would
!! result in an non-graded mesh. These mistakes are corrected, their status -1 or 0 is overwritten.
!! The status +1 is always conserved (recall to call respect_min_max_treelevel before).
!!
!!
!! Since 04/2017, the new code checks all blocks that want to coarsen or remain, NOT the ones that
!! want to refine, as was done in prototypes. The reason is MPI: I cannot easily set the flags of
!! my neighbors, as they might reside on another proc.
!!
!!
!! = log ======================================================================================
!! \n
!! 10/11/16 - switch to v0.4 \n
!! 23/11/16 - rework complete subroutine: use list of active blocks, procs works now on light data \n
!! 03/02/17 - insert neighbor_num variable to use subroutine for 2D and 3D data \n
!! 05/04/17 - Improvement: Ensure a graded mesh in any case, not only in the coarsen states (which was done before)
!! 09/06/17 - speed up with switching to 8bit integer for working arrays, shorten send/receive buffer
!
! ********************************************************************************************


subroutine ensure_gradedness( params, lgt_block, hvy_neighbor, lgt_active, lgt_n, lgt_sortednumlist )

    !---------------------------------------------------------------------------------------------
    ! modules

    !---------------------------------------------------------------------------------------------
    ! variables

    implicit none

    !> user defined parameter structure
    type (type_params), intent(in)      :: params
    !> light data array
    integer(kind=ik), intent(inout)     :: lgt_block(:, :)
    !> neighbor list
    integer(kind=ik), intent(inout)     :: hvy_neighbor(:, :)
    !> active_block_list (light data)
    integer(kind=ik), intent(inout)     :: lgt_active(:)
    integer(kind=tsize), intent(inout)  :: lgt_sortednumlist(:,:)
    !> number of active blocks (light data)
    integer(kind=ik), intent(in)        :: lgt_n

    ! MPI error variable
    integer(kind=ik)                    :: ierr
    ! process rank
    integer(kind=ik)                    :: rank
    ! loop variables
    integer(kind=ik)                    :: k, i, N, mylevel, neighbor_level, counter, hvy_id, neighbor_status, max_treelevel, proc_id, lgt_id
    ! status of grid changing
    logical                             :: grid_changed

    ! refinement status change, send/receive buffer, NOTE: use 8bit integers is inhibited
    ! here. I had severe problems which cost me several days on an IBM BLueGene/Q with just This
    ! kind=1 statement. I think the compiler had trouble with MPI_MAX in the ALLREDUCE statement
    integer(kind=ik), allocatable, save  :: refine_change( : ), my_refine_change( : )

    ! number of neighbor relations
    ! 2D: 16, 3D: 74
    integer(kind=ik) :: neighbor_num

    !---------------------------------------------------------------------------------------------
    ! interfaces

    !---------------------------------------------------------------------------------------------
    ! variables initialization

    ! allocate buffers, uses number of light data as maximum number for array length
    if (.not.allocated(refine_change)) allocate( refine_change(size(lgt_block,1)) )
    if (.not.allocated(my_refine_change)) allocate( my_refine_change(size(lgt_block,1)) )

    N = params%number_blocks
    max_treelevel = params%max_treelevel

    ! set MPI parameter
    rank = params%rank

    if ( params%threeD_case ) then
        ! 3D:
        neighbor_num = 74
    else
        ! 2D:
        neighbor_num = 16
    end if

    ! NOTE: The status +11 is required for ghost nodes synching, if the maxlevel
    ! is reached. It means just the same as 0 (stay) in the context of this routine

    !---------------------------------------------------------------------------------------------
    ! main body

    ! we repeat the ensure_gradedness procedure until this flag is .false. since as long
    ! as the grid changes due to gradedness requirements, we have to check it again
    grid_changed = .true. ! set true to trigger the loop
    counter = 0

    do while ( grid_changed )
        ! we hope not to set the flag to .true. again in this iteration
        grid_changed    = .false.

        ! We first remove the -1 flag from blocks which cannot be coarsened because their sisters
        ! disagree. If 1 of 4 or 1/8 blocks has 0 or +1 status, this cannot be changed. Therefore we first
        ! remove the status -1 from the blocks which have non-1 sisters. This is not only a question of
        ! simplicity. Consider 8 blocks on the same level:
        !      This block has to remove its -1 status as well, as the 4 neighbors to the right cannot coarsen
        !      v
        ! -1  -1  -1   0
        ! -1  -1  -1  -1
        ! It is thus clearly NOT enough to just look at the nearest neighbors in this ensure_gradedness routine.
        call ensure_completeness( params, lgt_block, lgt_active, lgt_n, lgt_sortednumlist )

        ! -------------------------------------------------------------------------------------
        ! first: every proc loop over the light data and calculate the refinement status change
        my_refine_change(1:lgt_n) = -99_ik
        refine_change(1:lgt_n) = -99_ik

        do k = 1, lgt_n

            ! calculate proc rank respondsible for current block
            call lgt_id_to_proc_rank( proc_id, lgt_active(k), N )
            ! proc is responsible for current block
            if ( proc_id == rank ) then
                ! Get this blocks heavy id
                call lgt_id_to_hvy_id( hvy_id, lgt_active(k), rank, N )

                !-----------------------------------------------------------------------
                ! This block wants to coarsen
                !-----------------------------------------------------------------------
                if ( lgt_block( lgt_active(k) , max_treelevel+2 ) == -1_ik) then
                    ! loop over all neighbors
                    do i = 1, neighbor_num
                        ! neighbor exists ? If not, this is a bad error
                        if ( hvy_neighbor( hvy_id, i ) /= -1_ik ) then

                            ! check neighbor treelevel
                            mylevel         = lgt_block( lgt_active(k), max_treelevel+1_ik )
                            neighbor_level  = lgt_block( hvy_neighbor( hvy_id, i ) , max_treelevel+1_ik )
                            neighbor_status = lgt_block( hvy_neighbor( hvy_id, i ) , max_treelevel+2_ik )

                            if (mylevel == neighbor_level) then
                                ! neighbor on same level
                                ! block can not coarsen, if neighbor wants to refine
                                if ( neighbor_status == -1_ik ) then
                                    ! neighbor wants to coarsen, as do I, we're on the same level -> ok
                                elseif ( neighbor_status == 0_ik .or. neighbor_status == 11_ik ) then
                                    ! neighbor wants to stay, I want to coarsen, we're on the same level -> ok
                                elseif ( neighbor_status == 1_ik ) then
                                    ! neighbor wants to refine, I want to coarsen, we're on the same level -> NOT OK
                                    ! I have at least to stay on my level.
                                    ! Note we cannot simply set 0 as we could accidentally overwrite a refinement flag
                                    my_refine_change( k ) = max( 0_ik, my_refine_change( k ) )
                                end if
                            elseif (mylevel - neighbor_level == 1_ik) then
                                ! neighbor on lower level
                                if ( neighbor_status == -1_ik ) then
                                    ! neighbor wants to coarsen, as do I, he is one level coarser, -> ok
                                elseif ( neighbor_status == 0_ik .or. neighbor_status == 11_ik ) then
                                    ! neighbor wants to stay, I want to coarsen, he is one level coarser, -> ok
                                elseif ( neighbor_status == 1_ik ) then
                                    ! neighbor wants to refine, I want to coarsen,  he is one level coarser, -> ok
                                end if
                            elseif (neighbor_level - mylevel == 1_ik) then
                                ! neighbor on higher level
                                ! neighbor wants to refine, ...
                                if ( neighbor_status == +1_ik) then
                                    ! ... so I also have to refine (not only can I NOT coarsen, I actually
                                    ! have to refine!)
                                    my_refine_change( k ) = +1_ik
                                elseif ( neighbor_status == 0_ik .or. neighbor_status == 11_ik) then
                                    ! neighbor wants to stay and I want to coarsen, but
                                    ! I cannot do that (there would be two levels between us)
                                    ! Note we cannot simply set 0 as we could accidentally overwrite a refinement flag
                                    my_refine_change( k ) = max( 0_ik, my_refine_change( k ) )
                                elseif ( neighbor_status == -1_ik) then
                                    ! neighbor wants to coarsen, which is what I want too,
                                    ! so we both would just go up one level together - that's fine
                                end if
                            else
                                call abort(785879, "ERROR: ensure_gradedness: my neighbor does not seem to have -1,0,+1 level diff!")
                            end if
                        end if ! if neighbor exists
                    end do ! loop over neighbors

                    !-----------------------------------------------------------------------
                    ! this block wants to stay on his level
                    !-----------------------------------------------------------------------
                elseif (lgt_block( lgt_active(k) , max_treelevel+2_ik ) == 0_ik .or. lgt_block( lgt_active(k) , max_treelevel+2_ik ) == 11_ik ) then
                    ! loop over all neighbors
                    do i = 1_ik, neighbor_num
                        ! neighbor exists ? If not, this is a bad error
                        if ( hvy_neighbor( hvy_id, i ) /= -1_ik ) then
                            mylevel     = lgt_block( lgt_active(k), max_treelevel+1_ik )
                            neighbor_level = lgt_block( hvy_neighbor( hvy_id, i ) , max_treelevel+1_ik )
                            neighbor_status = lgt_block( hvy_neighbor( hvy_id, i ) , max_treelevel+2_ik )

                            if (mylevel == neighbor_level) then
                                ! me and my neighbor are on the same level
                                ! As I'd wish to stay where I am, my neighbor is free to go -1,0,+1
                            elseif (mylevel - neighbor_level == 1_ik) then
                                ! my neighbor is one level coarser
                                ! My neighbor can stay or refine, but not coarsen. This case is however handled above (coarsening inhibited)
                            elseif (neighbor_level - mylevel == 1_ik) then
                                ! my neighbor is one level finer
                                if (neighbor_status == +1_ik) then
                                    ! neighbor refines (and we cannot inhibt that) so I HAVE TO do so as well
                                    my_refine_change( k ) = +1_ik
                                end if
                            else
                                call abort(785879, "ERROR: ensure_gradedness: my neighbor does not seem to have -1,0,+1 level diff!")
                            end if
                        end if ! if neighbor exists
                    end do
                end if ! my refinement status
            end if ! mpi responsibile for block
        end do ! loop over blocks


        ! second: synchronize local refinement changes.
        ! Now all procs have looked at their blocks, and they may have modified their blocks
        ! (remove coarsen states, force refinement through neighbors). None of the procs had to
        ! touch the neighboring blocks, there can be no MPI conflicts.
        ! So we can simply snynchronize and know what changes have to be made
        call MPI_Allreduce(my_refine_change(1:lgt_n), refine_change(1:lgt_n), lgt_n, MPI_INTEGER4, MPI_MAX, WABBIT_COMM, ierr)

        ! -------------------------------------------------------------------------------------
        ! third: change light data and set grid_changed status
        ! loop over active blocks
        do k = 1_ik, lgt_n
            lgt_id = lgt_active(k)
            ! refinement status changed
            if ( refine_change(k) > -99_ik ) then
                ! change light data
                lgt_block( lgt_id, max_treelevel+2_ik ) = max( lgt_block( lgt_id, max_treelevel+2_ik ), int(refine_change(k), kind=ik) )
                ! set grid status since if we changed something, we have to repeat the entire process
                grid_changed = .true.
            end if
        end do


        ! avoid infinite loops
        counter = counter + 1_ik
        if (counter == 10_ik) call abort(785877, "ERROR: unable to build a graded mesh")

    end do ! end do of repeat procedure until grid_changed==.false.

end subroutine ensure_gradedness
