// Quantize an incoming attribute by a defined number of steps, with smooth transitions between values
// adl_cop_smoothQuantizeByWidth.cl, by Andrew Louda
// Modified: 2024-07-21
// Copyright 2024 Andrew Louda. This file is licensed under the Apache 2.0 license.
// SPDX-License-Identifier: Apache-2.0

#include <interpolate.h>

#bind layer src float val=1
#bind layer !&dst

@KERNEL
{
    #bind layer step_count? float
    #bind parm step_count_ float val=5. 
    // [[parm=step_count_, min=1, max=10, default=5, disablewhen='{ hasinput(1) == 1 }']]
    float step_count = @step_count.bound ? @step_count : @step_count_;

    #bind layer width? float
    #bind parm width_ float val=.5
    // [[ parm=width_, default=0.5, disablewhen='{ hasinput(2) == 1 }']]
    float width = @width.bound ? @width : @width_;

    #bind layer enable_ramp? int
    #bind parm enable_ramp_ int val=0
    // adlParm[[ parm=enable_ramp_, type=toggle, disablewhen='{ hasinput(3) == 1 }']]
    int enable_ramp = @enable_ramp.bound ? @enable_ramp : @enable_ramp_;

    #bind ramp ramp_steps float val=0
    // adlFolder[[name=rampconfig,label='Step Ramp',type=collapsible,tags={'sidefx::header_toggle':'enable_ramp_'} ]]
    // adlParm[[ parm='ramp_steps', folder=rampconfig, disablewhen='{ enable_ramp_ == 0 hasinput(3) == 0 }' ]]

    float value = @src;

    float valfloor = floor( value*step_count ) / step_count;
    float remainder = (value-valfloor)*step_count;
    if(width == 0) width = 1e-6;
    width = (1-width)/2;
    float min = 0+width;
    float max = 1-width;
    
    remainder = fitTo01( remainder, min, max);
    if( enable_ramp ) remainder = @ramp_steps( remainder );

    value = valfloor+remainder/step_count;
    @dst.set(value);
}