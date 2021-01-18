-- config for modelling a drainage trench with constant groundwater flow

-- command line parameters
params =
{
--	physical parameters
	fs_depth = util.GetParamNumber("-fsDepth", 0.2), -- depth of the free surface at the right boundary
	fs_slope = util.GetParamNumber("-fsSlope", 0), -- initial slope of the free surface
	
	recharge = util.GetParamNumber("-recharge", 0.0000165), -- "rain"
}

params.baseLvl = ARGS.numPreRefs

-- additional constants for vanGenuchten
rhog = 9.81 * 1000

local henry = 
{ 
  -- The domain specific setup
  domain = 
  {
    dim = 2,
    grid = "grids/henry_quad_2x1.ugx",
    numRefs = ARGS.numRefs,
    numPreRefs = ARGS.numPreRefs,
  },

  -- list of non-linear models => translated to functions
  parameter = {  
    { uid = "@Silt",
      type = "vanGenuchten",
      thetaS = 0.396, thetaR = 0.131,
      alpha = 0.423*rhog, n = 2.06, Ksat= 4.745e-6},--4.96e-1 -- }, 
    
    { uid = "@Clay",  -- modified n
      type = "vanGenuchten",
      alpha = 0.152*rhog, n = 3.06,  
      thetaS = 0.446, thetaR = 0.1, 
      Ksat= 8.2e-4 * 1e-3,},  --KSat= kappa/mu*rh0*g   <=> kappa = Ksat*mu/(rho*g) 
    },

  flow = 
  {
    type = "haline",
    cmp = {"p", "c"},

    gravity = -9.81,    -- [ m s^{-2}�] ("standard", "no" or numeric value) 
    density =           
    { type = "linear",    -- density function ["linear", "exp", "ideal"]
      min = 1000, -- [ kg m^{-3} ] water density
      max = 1025.0,       -- [ kg m^{-3} ] saltwater density
      w_max = 1.0,
    },  
    
    viscosity = 
    { type = "const",      -- viscosity function ["const", "real"] 
      mu0 = 1e-3        -- [ kg m^{-3} ]  
    },
  },
   medium = 
   {
      {   subsets = {"Medium"}, 
          porosity = 0.35,
          saturation = 
          { type = "vanGenuchten",
            value = "@Silt",
          },
          conductivity =
          { type  = "vanGenuchten",
            value   = "@Silt",
          },
          diffusion   = 18.8571e-6,   -- constant
          permeability  = 1.019368e-9,  -- constant
      },
  },

  initial = 
  {
    { cmp = "c", value = 0.0 },
    { cmp = "p", value = "HydroPressure" },		
  },

  boundary = 
  {
    { cmp = "c", type = "dirichlet", bnd = "Inflow", value = 0.0 },
    { cmp = "c", type = "dirichlet", bnd = "Sea", value = 1.0 },
    { cmp = "p", type = "dirichlet", bnd = "Sea", value = "HydroPressure_bnd" },
    --{ cmp = "p", type = "dirichlet", bnd = "Top", value = 0.0 }, -- if the FS intersects the top
    { cmp = "c", type = "dirichlet", bnd = "Top", value = 0.0 } -- if the FS intersects the top

  },

  solver =
  {
      type = "newton",
      lineSearch = {			   		-- ["standard", "none"]
          type = "standard",
          maxSteps		= 10,		-- maximum number of line search steps
          lambdaStart		= 1,		-- start value for scaling parameter
          lambdaReduce	= 0.5,		-- reduction factor for scaling parameter
          acceptBest 		= true,		-- check for best solution if true
          checkAll		= false		-- check all maxSteps steps if true 
      },

      convCheck = {
          type		= "standard",
          iterations	= 10,			-- number of iterations
          absolute	= 1e-8,			-- absolut value of defact to be reached; usually 1e-6 - 1e-9
          reduction	= 1e-7,		-- reduction factor of defect to be reached; usually 1e-6 - 1e-7
          verbose		= true			-- print convergence rates if true
      },
      
      linSolver =
      {
          type = "bicgstab",			-- linear solver type ["bicgstab", "cg", "linear"]
          precond = 
          {	
              type 		= "gmg",	-- preconditioner ["gmg", "ilu", "ilut", "jac", "gs", "sgs"]
              smoother 	= {type = "ilu", overlap = true},	-- gmg-smoother ["ilu", "ilut", "jac", "gs", "sgs"]
              cycle		= "V",		-- gmg-cycle ["V", "F", "W"]
              preSmooth	= 3,		-- number presmoothing steps
              postSmooth 	= 3,		-- number postsmoothing steps
              rap			= true,		-- comutes RAP-product instead of assembling if true 
              baseLevel	= params.baseLvl, -- gmg - baselevel
              
          },
          convCheck = {
              type		= "standard",
              iterations	= 30,		-- number of iterations
              absolute	= 0.5e-8,	-- absolut value of defact to be reached; usually 1e-8 - 1e-10 (must be stricter / less than in newton section)
              reduction	= 1e-7,		-- reduction factor of defect to be reached; usually 1e-7 - 1e-8 (must be stricter / less than in newton section)
              verbose		= true,		-- print convergence rates if true
          }
      }
  },
   
  time = 
  {
      control	= "limex",
      start 	= 0.0,				-- [s]  start time point
      stop	= 100000,			-- [s]  end time point
      max_time_steps = 1000,		-- [1]	maximum number of time steps
      dt		= ARGS.dt,		-- [s]  initial time step
      dtmin	= 0.00001 * ARGS.dt,	-- [s]  minimal time step
      dtmax	= 10 * ARGS.dt,	-- [s]  maximal time step
      dtred	= 0.1,				-- [1]  reduction factor for time step
      tol 	= 1e-2,
  },
}

function HydroPressure_bnd(x, y, t, si) 
  p = HydroPressure(x, y)
  if p < 0 then
    return false, 0
  else
    return true, p
  end
end

function HydroPressure(x, y) 
  return -10055.25 * (y + params.fs_depth)
end

return henry
