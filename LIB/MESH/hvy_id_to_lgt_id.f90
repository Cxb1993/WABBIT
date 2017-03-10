!> \file
! ********************************************************************************************
! WABBIT
! ============================================================================================
!> \name hvy_id_to_lgt_id.f90
!> \version 0.4
!> \author msr
!
! convert heavy id into light id
!
! input:    - heavy id, proc rank, number of blocks per proc
! output:   - ligth data id
!
! = log ======================================================================================
!
! 23/11/16 - create
! ********************************************************************************************

subroutine hvy_id_to_lgt_id( lgt_id, hvy_id, rank, N )

!---------------------------------------------------------------------------------------------
! modules

    ! global parameters
    use module_params

!---------------------------------------------------------------------------------------------
! variables

    implicit none

    ! heavy id
    integer(kind=ik), intent(in)        :: hvy_id

    ! light id
    integer(kind=ik), intent(out)       :: lgt_id

    ! rank of proc
    integer(kind=ik), intent(in)        :: rank

    ! number of blocks per proc
    integer(kind=ik), intent(in)        :: N

!---------------------------------------------------------------------------------------------
! interfaces

!---------------------------------------------------------------------------------------------
! variables initialization

!---------------------------------------------------------------------------------------------
! main body

    lgt_id = rank*N + hvy_id

end subroutine hvy_id_to_lgt_id
