export resolvecollision!, evolve!, construct, isphysical


function resolvecollision!(p::MagneticParticle, a::Antidot, T::Function, θ::Function,
  new_ω::Function = ((x, bool) -> x))
  dt = 0.0
  ω = p.omega
  # Determine incidence angle (0 < θ < π/4)
  n = normalvec(a, p.pos)
  φ = acos(dot(p.vel, -n))
  # if this is wrong then my normal vec is wrong:
  if φ >= π/2
    println("φ=$φ")
    error("φ shoud be between 0 and π/2")
  end
  # ray-splitting (step 2)
  if T(φ, a.where, ω) > rand()
    # Step 3
    if cross2D(p.vel, n) < 0
      φ *= -1
    end
    # Step 4
    theta = θ(φ, a.where, ω)
    # Step 5
    a.where = !a.where
    # Step 6
    n = normalvec(a, p.pos) #notice that this is reversed! It's the new!
    Θ = theta + atan2(n[2], n[1])
    # Step 7
    dist = distance(p, a)  #this is also reversed! It's the new distance!
    # Step 8
    if dist < 0.0
      dt = relocate!(p, a, dist)
    end
    # Step 9
    p.vel = [cos(Θ), sin(Θ)]
    # Step 10
    p.omega = new_ω(ω, !a.where)  # notice the exclamation mark !
  # No ray-splitting:
  else
    dist = distance(p, a)
    dt = 0.0

    if dist < 0.0
      dt = relocate!(p, a, dist)
    end
    #perform specular
    specular!(p, a)
  end

  return dt
end

function resolvecollision!(p::Particle, a::Antidot, T::Function, θ::Function)

  dt = 0.0
  ω = 0.0
  # Determine incidence angle (0 < θ < π/4)
  n = normalvec(a, p.pos)
  φ = acos(dot(p.vel, -n))
  # if this is wrong then my normal vec is wrong:
  if φ >= π/2
    println("φ=$φ")
    if a.where == true
      println("Particle should be coming from outside of disk")
    else
      println("Particle should be coming from inside of disk")
    end
    plot_particle(p)
    error("φ shoud be between 0 and π/2")
  end
  # ray-splitting (step 2)
  if T(φ, a.where, ω) > rand()
    # Step 3
    if cross2D(p.vel, n) < 0
      φ *= -1
    end
    # Step 4
    theta = θ(φ, a.where, ω)
    # Step 5
    a.where = !a.where
    # Step 6
    n = normalvec(a, p.pos) #notice that this is reversed! It's the new!
    Θ = theta + atan2(n[2], n[1])
    # Step 7
    dist = distance(p, a)  #this is also reversed! It's the new distance!
    # Step 8
    if dist < 0.0
      dt = relocate!(p, a, dist)
    end
    # Step 9
    p.vel = [cos(Θ), sin(Θ)]
  # No ray-splitting:
  else
    dist = distance(p, a)
    if dist < 0.0
      dt = relocate!(p, a, dist)
    end
    #perform specular
    specular!(p, a)
  end

  return dt
end

# For Particle and Ray-Splitting:
function evolve!(p::Particle, bt::Vector{Obstacle}, ttotal::Float64,
  ray::Dict{Int, Vector{Function}})

  rt = Float64[]
  rpos = SVector{2,Float64}[]
  rvel = SVector{2,Float64}[]
  push!(rpos, p.pos)
  push!(rvel, p.vel)
  push!(rt, 0.0)
  tcount = 0.0
  colobst = bt[1]
  #prev_obst = bt[1]
  colind::Int = length(bt)
  t_to_write = 0.0


  while tcount < ttotal
    tmin = Inf

    for i in eachindex(bt)
      obst = bt[i]
      tcol = collisiontime(p, obst)
      # Set minimum time:
      if tcol < tmin
        tmin = tcol
        colobst = obst
        colind = i
      end
    end#obstacle loop
    # if tmin < 1e-10 && tcount!=0
    #   println("-----------------")
    #   plot_particle(p)
    #   println("In raysplit evolve, tmin = $tmin")
    #   println("tcount = $tcount")
    #   println("Collision is to happen with $(colobst.name)")
    #   println("Antidot state: where = $(bt[5].where)")
    #   println("Previous collision with: $(prev_obst.name)")
    #
    # end

    propagate!(p, tmin)
    if haskey(ray, colind)
      dt = resolvecollision!(p, colobst, ray[colind][1], ray[colind][2])
    else
      dt = resolvecollision!(p, colobst)
    end
    t_to_write += tmin + dt
    #prev_obst = colobst

    if typeof(colobst) <: PeriodicWall
      continue
    else
      push!(rpos, p.pos + p.current_cell)
      push!(rvel, p.vel)
      push!(rt, t_to_write)
      tcount += t_to_write
      t_to_write = 0.0
    end
  end#time loop
  return (rt, rpos, rvel)
end

# For MagneticParticle and Ray-Splitting. Returns one extra vector with omegas!!!
function evolve!(p::MagneticParticle, bt::Vector{Obstacle},
                 ttotal::Float64, ray::Dict{Int, Vector{Function}})

  omegas = Float64[]
  rt = Float64[]
  rpos = SVector{2,Float64}[]
  rvel = SVector{2,Float64}[]
  push!(rpos, p.pos)
  push!(rvel, p.vel)
  push!(rt, zero(Float64))
  push!(omegas, p.omega)

  tcount = 0.0
  t_to_write = 0.0
  colobst = bt[1]
  #prev_obst = bt[1]
  colind = 1

  while tcount < ttotal
    tmin = Inf

    for i in eachindex(bt)
      obst = bt[i]
      tcol = collisiontime(p, obst)
      # Set minimum time:
      if tcol < tmin
        tmin = tcol
        colobst = obst
        colind = i
      end
    end#obstacle loop

    if tmin == Inf
      println("pinned particle! (Inf col t)")
      push!(rpos, rpos[end])
      push!(rvel, rvel[end])
      push!(rt, Inf)
      return (rt, rpos, rvel)
    end
    # if tmin < 1e-10 && tcount!=0
    #         println("-----------------")
    #   println("In raysplit evolve, tmin = $tmin")
    #   println("tcount = $tcount")
    #   println("Collision is to happen with $(colobst.name)")
    #   println("Antidot state: where = $(bt[5].where)")
    #   println("Previous collision with: $(prev_obst.name)")
    # end

    propagate!(p, tmin)
    if haskey(ray, colind)
      dt = resolvecollision!(p, colobst, ray[colind][1], ray[colind][2], ray[colind][3])
    else
      dt = resolvecollision!(p, colobst)
    end
    t_to_write += tmin + dt
    # Write output only if the collision was not made with PeriodicWall
    if typeof(colobst) <: PeriodicWall
      # Pinned particle:
      if t_to_write >= 2π/p.omega
        println("pinned particle! (completed circle)")
        push!(rpos, rpos[end])
        push!(rvel, rvel[end])
        push!(rt, Inf)
        push!(omegas, p.omega)
        return (rt, rpos, rvel)
      end
      #If not pinned, continue (do not write for PeriodicWall)
      continue
    else
      push!(rpos, p.pos + p.current_cell)
      push!(rvel, p.vel)
      push!(rt, t_to_write)
      push!(omegas, p.omega)
      tcount += t_to_write
      t_to_write = 0.0
    end
    #prev_obst = colobst
  end#time loop
  return (rt, rpos, rvel, omegas)
end

function construct(t::Vector{Float64}, poss::Vector{SVector{2,Float64}},
  vels::Vector{SVector{2,Float64}}, omegas::Vector{Float64}, dt=0.01)

  xt = [poss[1][1]]
  yt = [poss[1][2]]
  vxt= [vels[1][1]]
  vyt= [vels[1][2]]
  ts = [t[1]]
  ct = cumsum(t)

  for i in 2:length(t)
    ω = omegas[i-1]
    φ0 = atan2(vels[i-1][2], vels[i-1][1])
    x0 = poss[i-1][1]; y0 = poss[i-1][2]
    colt=t[i]

    t0 = ct[i-1]
    # Construct proper time-vector
    if colt >= dt
      timevec = collect(0:dt:colt)[2:end]
      timevec[end] == colt || push!(timevec, colt)
    else
      timevec = colt
    end

    for td in timevec
      push!(vxt, cos(ω*td + φ0))
      push!(vyt, sin(ω*td + φ0))
      push!(xt, sin(ω*td + φ0)/ω + x0 - sin(φ0)/ω)  #vy0 is sin(φ0)
      push!(yt, -cos(ω*td + φ0)/ω + y0 + cos(φ0)/ω) #vx0 is cos(φ0)
      push!(ts, t0 + td)
    end#collision time
  end#total time
  return xt, yt, vxt, vyt, ts
end

"""
    isphysical(ray::Dict{Int, Vector{Function}}; check_symmetry = true)
Return `true` if the given ray-splitting dictionary represends the physical world.

Specifically, check if:
* Transmission probability T(φ) is even function.
* Refraction angle θ(φ) is odd function (φ is the incidence angle).
* If θ(φ) > π/2 then T(φ) ≤ 0 ?
* If ray-reversal is true: θ(θ(φ, where, ω), !where, ω) ≈ φ
The first two checks are optional.
"""
function isphysical(ray::Dict{Int, Vector{Function}}; check_symmetry::Bool = true)
  for i in keys(ray)
    scatter = ray[i][2]
    tr = ray[i][1]
    om = ray[i][3]
    range = -π/2:0.001:π/2
    orange = -1.0:0.01:1.0
    for where in [true, false]
      for ω in orange
        for φ in range
          θ = scatter(φ, where, ω)
          T = tr(φ, where, ω)
          # Check symmetry:
          if check_symmetry
            if !isapprox(θ, -scatter(-φ, where, ω))
              es = "Scattering angle function is not odd!\n"
              es *="For index = $i, tested with φ = $φ, where = $where, ω = $ω"
              println(es)
              return false
            end
            if !isapprox(T, tr(-φ, where, ω))
              es = "Transmission probability function is not even!\n"
              es *="For index = $i, tested with φ = $φ, where = $where, ω = $ω"
              println(es)
              return false
            end
          end
          # Check critical angle:
          if θ >= π/2 && T > 0
            es = "Refraction angle > π/2 and T > 0 !\n"
            es*= "For index = $i, tested with φ = $φ, where = $where, ω = $ω"
            println(es)
            return false
          end
          # Check ray-reversal:
          if !isapprox(scatter(θ, !where, ω), φ)
            es = "Ray-reversal does not hold!\n"
            es *="For index = $i, tested with φ = $φ, where = $where, ω = $ω"
            println(es)
            return false
          end
        end#φ range
      end#ω range
    end#where range
  end#obstacle range
  return true
end