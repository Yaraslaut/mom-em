! MODULE: diffr
! AUTHOR: Jouni Makitalo
! DESCRIPTION:
! Routines for computing diffracted power in two-dimensionally periodic problems.
MODULE diffr
  USE source
  USE nfields
  USE common

  IMPLICIT NONE

CONTAINS
  ! Far-field approximation of the periodic Green function (spectral series form).
  FUNCTION Gpff(r, rp, k, prd, i, j) RESULT(g)
    REAL (KIND=dp), DIMENSION(3), INTENT(IN) :: r, rp
    TYPE(prdnfo), POINTER, INTENT(IN) :: prd
    COMPLEX (KIND=dp), INTENT(IN) :: k

    ! Diffraction orders.
    INTEGER, INTENT(IN) :: i, j

    COMPLEX (KIND=dp) :: g

    REAL (KIND=dp), DIMENSION(2) :: kt
    COMPLEX (KIND=dp) :: kz, phasor
    REAL (KIND=dp) :: sgn, A

    IF(r(3)>rp(3)) THEN
       sgn = 1.0_dp
    ELSE
       sgn = -1.0_dp
    END IF

    g = 0.0_dp
          
    ! Lattice vector.
    kt = (/prd%coef(prd%cwl)%k0x + 2.0_dp*PI*(i/(prd%dx*prd%cp)&
         - j*prd%sp/(prd%dy*prd%cp)) ,&
         prd%coef(prd%cwl)%k0y + 2.0_dp*PI*j/prd%dy/)
    
    ! Skip evanescent waves.
    IF(REAL(k**2,KIND=dp)<dotr(kt,kt)) THEN
       RETURN
    END IF
    
    kz = SQRT(k**2 - dotr(kt,kt))
    
    phasor = EXP((0,1)*dotr(kt,r(1:2)))*EXP(-(0,1)*dotr(kt,rp(1:2)))*&
         EXP(sgn*(0,1)*kz*r(3))*EXP(-sgn*(0,1)*kz*rp(3))
    
    g = phasor/kz

    A = prd%dx*prd%dy*prd%cp

    g = g*(0,1)/(2*A)
  END FUNCTION Gpff

  ! Far-field approximation of the periodic Green function gradient (spectral series form).
  FUNCTION gradGpff(r, rp, k, prd, i, j) RESULT(gg)
    REAL (KIND=dp), DIMENSION(3), INTENT(IN) :: r, rp
    TYPE(prdnfo), POINTER, INTENT(IN) :: prd
    COMPLEX (KIND=dp), INTENT(IN) :: k

    ! Diffraction orders.
    INTEGER, INTENT(IN) :: i, j

    COMPLEX (KIND=dp), DIMENSION(3) :: gg

    REAL (KIND=dp), DIMENSION(2) :: kt
    COMPLEX (KIND=dp) :: kz, phasor
    REAL (KIND=dp) :: sgn, A

    IF(r(3)>rp(3)) THEN
       sgn = 1.0_dp
    ELSE
       sgn = -1.0_dp
    END IF

    gg(:) = 0.0_dp
          
    ! Lattice vector.
    kt = (/prd%coef(prd%cwl)%k0x + 2.0_dp*PI*(i/(prd%dx*prd%cp)&
         - j*prd%sp/(prd%dy*prd%cp)) ,&
         prd%coef(prd%cwl)%k0y + 2.0_dp*PI*j/prd%dy/)
    
    ! Skip evanescent waves.
    IF(REAL(k**2,KIND=dp)<dotr(kt,kt)) THEN
       RETURN
    END IF
    
    kz = SQRT(k**2 - dotr(kt,kt))
    
    phasor = EXP((0,1)*dotr(kt,r(1:2)))*EXP(-(0,1)*dotr(kt,rp(1:2)))*&
         EXP(sgn*(0,1)*kz*r(3))*EXP(-sgn*(0,1)*kz*rp(3))
    
    gg(1:2) = kt*phasor/kz
    gg(3) = sgn*phasor

    A = prd%dx*prd%dy*prd%cp

    gg(:) = gg(:)/(2*A)
  END FUNCTION gradGpff

  ! Computes the fields diffracted to order (i,j).
  SUBROUTINE diff_fields(mesh, ga, nf, x, nedgestot, omega, ri, prd, r, i, j, qd, e, h)
    TYPE(mesh_container), INTENT(IN) :: mesh
    COMPLEX (KIND=dp), INTENT(IN) :: ri
    REAL (KIND=dp), INTENT(IN) :: omega
    TYPE(group_action), DIMENSION(:), INTENT(IN) :: ga
    INTEGER, INTENT(IN) :: nf, nedgestot, i, j
    TYPE(prdnfo), POINTER, INTENT(IN) :: prd
    COMPLEX (KIND=dp), DIMENSION(:), INTENT(IN) :: x
    REAL (KIND=dp), DIMENSION(3), INTENT(IN) :: r
    TYPE(quad_data), INTENT(IN) :: qd

    COMPLEX (KIND=dp), DIMENSION(3), INTENT(INOUT) :: e, h

    REAL (KIND=dp), DIMENSION(3,qd%num_nodes) :: qpn
    INTEGER :: n, q, t, edgeind
    COMPLEX (KIND=dp) :: c1, c2, g, k
    COMPLEX (KIND=dp), DIMENSION(3) :: gg
    REAL (KIND=dp), DIMENSION(3) :: divfn
    REAL (KIND=dp), DIMENSION(3,qd%num_nodes,3) :: fv
    REAL (KIND=dp) :: An

    k = ri*omega/c0    
    c1 = (0,1)*omega*mu0
    c2 = (0,1)*omega*(ri**2)*eps0

    e(:) = 0.0_dp
    h(:) = 0.0_dp

    DO n=1,mesh%nfaces
       An = mesh%faces(n)%area
       qpn = quad_tri_points(qd, n, mesh)

       DO q=1,3
          CALL vrwg(qpn(:,:),n,q,mesh,fv(:,:,q))
          divfn(q) = rwgDiv(n,q,mesh)
       END DO

       DO t=1,qd%num_nodes
          g = Gpff(r, qpn(:,t), k, prd, i, j)
          gg = gradGpff(r, qpn(:,t), k, prd, i, j)

          DO q=1,3
             edgeind = mesh%faces(n)%edge_indices(q)
             edgeind = mesh%edges(edgeind)%parent_index

             e = e + qd%weights(t)*An*( c1*g*fv(:,t,q)*x(edgeind) + gg*divfn(q)*x(edgeind)/c2 +&
                  crossc(gg, CMPLX(fv(:,t,q),KIND=dp))*x(edgeind + nedgestot) )

             h = h + qd%weights(t)*An*( c2*g*fv(:,t,q)*x(edgeind + nedgestot) +&
                  gg*divfn(q)*x(edgeind + nedgestot)/c1 -&
                  crossc(gg, CMPLX(fv(:,t,q),KIND=dp))*x(edgeind) )
          END DO
       END DO
    END DO
  END SUBROUTINE diff_fields

  ! Calculates the irradiance diffracted to order (i,j).
  ! Can also simulate a linear polarization filter at detector.
  ! Assumes that the diffracted fields propagate to half-space z<0.
  FUNCTION diff_irradiance(mesh, ga, addsrc, src, x, nedgestot, omega, ri, ri_inc, prd, i, j, qd,&
       polarize, polangle) RESULT(irr)
    TYPE(mesh_container), INTENT(IN) :: mesh
    LOGICAL, INTENT(IN) :: addsrc, polarize
    TYPE(srcdata), INTENT(IN) :: src
    COMPLEX (KIND=dp), INTENT(IN) :: ri, ri_inc
    REAL (KIND=dp), INTENT(IN) :: omega, polangle
    TYPE(group_action), DIMENSION(:), INTENT(IN) :: ga
    INTEGER, INTENT(IN) :: nedgestot, i, j
    TYPE(prdnfo), POINTER, INTENT(IN) :: prd
    COMPLEX (KIND=dp), DIMENSION(:,:), INTENT(IN) :: x
    TYPE(quad_data), INTENT(IN) :: qd

    REAL (KIND=dp) :: irr, pinc, eval_dist, k
    INTEGER :: nf
    REAL (KIND=dp), DIMENSION(3) :: dir, poldir
    COMPLEX (KIND=dp), DIMENSION(3) :: e, h, einc, hinc
    REAL (KIND=dp), DIMENSION(2) :: kt

    nf = 1

    ! Field evaluation distance. Arbitrary positive value.
    ! For good numerical accuracy, should be on the order of
    ! wavelength.
    eval_dist = 1e-6

    !dir = get_dir(pwtheta, pwphi)

    k = REAL(ri,KIND=dp)*omega/c0

    kt = (/prd%coef(prd%cwl)%k0x + 2.0_dp*PI*(i/(prd%dx*prd%cp)&
         - j*prd%sp/(prd%dy*prd%cp)) ,&
         prd%coef(prd%cwl)%k0y + 2.0_dp*PI*j/prd%dy/)

    ! Skip evanescent waves.
    IF(REAL(k**2,KIND=dp)<dotr(kt,kt)) THEN
       irr = 0.0_dp
       RETURN
    END IF

    dir = (/kt(1), kt(2), -SQRT(k**2 - dotr(kt,kt))/)

    dir = dir/normr(dir)

    CALL diff_fields(mesh, ga, nf, x(:,nf), nedgestot, omega, ri, prd, dir*eval_dist, i, j, qd, e, h)

    IF(addsrc .AND. i==0 .AND. j==0) THEN
       CALL src_fields(src, omega, ri, dir*eval_dist, einc, hinc)
       
       e = e + einc
       h = h + hinc
    END IF

    pinc = REAL(ri_inc,KIND=dp)/(c0*mu0)

    ! Use polarizer at output?
    IF(polarize) THEN
       ! Reference polarizator pass direction is orthogonal to x-axis.
       poldir = crossr(dir, (/1.0_dp,0.0_dp,0.0_dp/))
       poldir = poldir/normr(poldir)

       poldir = rotate_vector(poldir, dir, polangle)

       WRITE(*,*) poldir

       e = dotc(CMPLX(poldir,KIND=dp), e)*poldir
       h = dotc(CMPLX(crossr(dir, poldir),KIND=dp), h)*crossr(dir, poldir)
    END IF
    
    ! The relative irradiance diffracted to 0th order in the given domain.
    irr = dotr(REAL(crossc(e, CONJG(h)), KIND=dp), dir)/pinc
    !irr = normc(crossc(CMPLX(dir,KIND=dp),e))*k/(omega*mu0*pinc)

  END FUNCTION diff_irradiance

  ! Calculates the transmittance to half-space z<0 or z>0 by integrating the Poynting vector
  ! in the near-field. All diffraction orders are then included.
  FUNCTION transmittance(mesh, ga, addsrc, src, x, nedgestot, omega, ri, ri_inc, prd,&
       z0, zsign, qd) RESULT(power)
    TYPE(mesh_container), INTENT(IN) :: mesh
    LOGICAL, INTENT(IN) :: addsrc
    TYPE(srcdata), DIMENSION(:), INTENT(IN) :: src
    COMPLEX (KIND=dp), INTENT(IN) :: ri, ri_inc
    REAL (KIND=dp), INTENT(IN) :: omega
    TYPE(group_action), DIMENSION(:), INTENT(IN) :: ga
    INTEGER, INTENT(IN) :: nedgestot
    TYPE(prdnfo), POINTER, INTENT(IN) :: prd
    COMPLEX (KIND=dp), DIMENSION(:,:,:), INTENT(IN) :: x
    REAL (KIND=dp), INTENT(IN) :: z0, zsign
    TYPE(quad_data), INTENT(IN) :: qd

    REAL (KIND=dp), DIMENSION(SIZE(src)) :: power
    REAL (KIND=dp), DIMENSION(:), ALLOCATABLE :: qwx, ptx, qwy, pty
    COMPLEX (KIND=dp), DIMENSION(3,SIZE(src)) :: e, h
    COMPLEX (KIND=dp), DIMENSION(3) :: einc, hinc, poynting
    COMPLEX (KIND=dp) :: k
    REAL (KIND=dp), DIMENSION(3) :: pt
    REAL (KIND=dp) :: hdx, hdy, pinc
    INTEGER :: n, m, nx, ny, nsrc
    REAL (KIND=dp), DIMENSION(3) :: xaxis, yaxis

    ! Wavenumber in diffraction medium.
    k = ri*omega/c0

    ! Select the number of integration points based on wavelength and period.
    !nx = NINT(prd%dx/b%sols(wlindex)%wl*20)
    !ny = NINT(prd%dy/b%sols(wlindex)%wl*20)
    nx = 51
    ny = 51

    ! Make sure that the numbers are odd.
    IF(MOD(nx,2)==0) THEN
       nx = nx + 1
    END IF

    IF(MOD(ny,2)==0) THEN
       ny = ny + 1
    END IF

    ALLOCATE(qwx(1:nx), ptx(1:nx), qwy(1:ny), pty(1:ny))

    hdx = prd%dx*0.5_dp
    hdy = prd%dy*0.5_dp

    xaxis = (/prd%cp, prd%sp, 0.0_dp/)
    yaxis = (/0.0_dp, 1.0_dp, 0.0_dp/)

    ! Compute weights and nodes from Simpson's rule.
    CALL get_simpsons_weights(-hdx, hdx, nx-1, qwx)
    CALL get_simpsons_points(-hdx, hdx, nx-1, ptx)
    CALL get_simpsons_weights(-hdy, hdy, ny-1, qwy)
    CALL get_simpsons_points(-hdy, hdy, ny-1, pty)

    power(:) = 0.0_dp

!    !$OMP PARALLEL DEFAULT(NONE)&
!    !$OMP SHARED(ny,nx,z0,xaxis,yaxis,ptx,pty,mesh,ga,x,nedgestot,omega,ri,prd,addsrc,src,qwx,qwy,zsign,power,qd)&
!    !$OMP PRIVATE(m,n,pt,einc,hinc,e,h,poynting,nsrc)
!    !$OMP DO REDUCTION(+:power) SCHEDULE(STATIC)
    DO m=1,ny
       DO n=1,nx

          pt = (/0.0_dp,0.0_dp,z0/) + xaxis*ptx(n) + yaxis*pty(m)
          
          CALL scat_fields(mesh, ga, x, nedgestot, omega, ri, prd, pt, qd, e, h)

          DO nsrc=1,SIZE(src)
             IF(addsrc) THEN
                CALL src_fields(src(nsrc), omega, ri, pt, einc, hinc)
                
                e(:,nsrc) = e(:,nsrc) + einc
                h(:,nsrc) = h(:,nsrc) + hinc
             END IF
             
             poynting = crossc(e(:,nsrc), CONJG(h(:,nsrc)))
             
             power(nsrc) = power(nsrc) + 0.5_dp*qwx(n)*qwy(m)*REAL(poynting(3)*zsign)
          END DO
       END DO
    END DO
!    !$OMP END DO
!    !$OMP END PARALLEL
        
    ! cp is the Jacobian of the area integration.
    power(:) = power(:)*prd%cp

    pinc = 0.5_dp*prd%dx*prd%dy*prd%cp*REAL(ri_inc,KIND=dp)/(c0*mu0)
    
    ! Relative power.
    power(:) = power(:)/pinc

    DEALLOCATE(qwx, ptx, qwy, pty)

  END FUNCTION transmittance
END MODULE diffr
