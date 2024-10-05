// Inspired by the post-processing system that comes with the maxon noise system. This allows for per-shading-point variation and use outside of maxon noise.
// adl_cop_mxPost.cl, by Andrew Louda
// Modified: 2024-07-21 - Added ringid output, useful for varying outputs downstream
// Copyright 2024 Andrew Louda. This file is licensed under the Apache 2.0 license.
// SPDX-License-Identifier: Apache-2.0

#bind layer src
#bind layer !&dst
#bind layer !&ringid

float fit(float valin, float InStart, float InEnd, float OutStart, float OutEnd){
    float fac = (clamp(valin,InStart,InEnd) - InStart) / (InEnd - InStart);
    return OutStart + fac * (OutEnd - OutStart);
}

float mx_Cycle(float In, float fmodval, float cycles_phase, int smoothcycles){
    float outval;
    #define fmod_setup(In,fmodval) (fabs(fmod(In+cycles_phase/fmodval*2.0f,1.0f/(fmodval*0.5f))*(fmodval*0.5f)))
    #define rerange(val) (1.0f-(fabs(val-0.5f)*2.0f))
    //This is not a pixel-perfect match with the smoothing used within maxon noise's cycles, but it's incredibly close. This function is seemingly identical to the inbuilt smoothstep function.
    #define BezierBlend(t) (t*t*(3.0f-2.0f*t))
    if(fmodval >= 1){
        outval = fmod_setup( In, fmodval);
        outval = rerange(outval);
        if(smoothcycles){
            outval = BezierBlend(outval);
        }
    }
    else{
        outval = fmod_setup( In, 1);
        outval = rerange(outval);
        if(smoothcycles){
            outval = BezierBlend(outval);
        }
        outval = mix(In, outval, fmodval);
    }
    return outval;
}

float mx_Clip(float colorcomp, float lowclip, float highclip){
    float Out;
    if( lowclip == highclip ){
        Out = colorcomp>=lowclip?1:0;
    }
    else{
        Out = fit(colorcomp, lowclip, highclip, 0.0f, 1.0f);
    }
    return Out;
}

float mx_Brightness(float In, float brightness){
    float Out = clamp(In + brightness, 0.0f, 1.0f);
    return Out;
}

float mx_Contrast(float colorcomp, float contrast){
    float colorout;
    if(contrast==1){
        colorout = colorcomp>=0.5?1:0;
    }
    else if(contrast>0){
        float distance = (1-contrast)/2;        
        colorout = fit(colorcomp, 0.5-distance, 0.5+distance, 0, 1);
    }
    else if(contrast==-1){
        colorout = 0.5;
    }
    else if(contrast<0){
        float distance = (contrast*-1)/2;
        colorout = fit(colorcomp, 0, 1, 0+distance, 1-distance);
    }
    return colorout;
}

@KERNEL
{
    #bind layer cycles? float
    #bind parm cycles_ float val=0 
    // [[parm='cycles_', default=0, min=0, max=10, disablewhen='{ hasinput(1) == 1 }']]
    float cycles = @cycles.bound ? @cycles : @cycles_;
    
    #bind layer cycles_phase? float
    #bind parm cycles_phase_ float val=0 
    // [[parm='cycles_phase_', default=0, min=-1, max=1, disablewhen='{ hasinput(2) == 1 }']]
    float cycles_phase = @cycles_phase.bound ? @cycles_phase : @cycles_phase_;

    #bind layer smooth_cycles? int
    #bind parm smooth_cycles_ int val=1
    // [[parm=smooth_cycles_, default=1, type=toggle, disablewhen='{ hasinput(3) == 1 }']]
    int smooth_cycles = @smooth_cycles.bound ? @smooth_cycles : @smooth_cycles_;

    #bind layer lowclip? float
    #bind parm low_clip_ float val=0
    // [[parm='low_clip_', default=0, min=0, max=1, minlock=1, maxlock=1, disablewhen='{ hasinput(4) == 1 }']]
    float lowclip = @lowclip.bound ? @lowclip : @low_clip_;

    #bind layer highclip? float
    #bind parm high_clip_ float val=1
    // [[parm='high_clip_', default=1, min=0, max=1, minlock=1, maxlock=1, disablewhen='{ hasinput(5) == 1 }']]
    float highclip = @highclip.bound ? @highclip : @high_clip_;

    #bind layer brightness? float
    #bind parm brightness_ float val=0
    // [[parm='brightness_', default=0, min=-1, max=1, minlock=1, maxlock=1, disablewhen='{ hasinput(7) == 1 }']]
    float brightness = @brightness.bound ? @brightness : @brightness_;

    #bind layer contrast? float
    #bind parm contrast_ float val=0
    // [[parm='contrast_', default=0, min=-1, max=1, minlock=1, maxlock=1, disablewhen='{ hasinput(7) == 1 }']]
    float contrast = @contrast.bound ? @contrast : @contrast_;
    
    #if @src.channels == 1
        float val = @src[0];
        float ringid = 0;
        if(cycles>0){
            ringid = rint((val*cycles/2)+cycles_phase-0.5);
            val = mx_Cycle(val,cycles,cycles_phase,smooth_cycles);
        }
        if(lowclip > 0 || highclip < 1){
            val = mx_Clip(val,lowclip,highclip);
        }
        if(brightness != 0){
            val = mx_Brightness(val,brightness);
        }
        if(contrast != 0){
            val = mx_Contrast(val,contrast);
        }
        @dst.set(val);
        @ringid.set(ringid);
    #endif
    #if @src.channels > 1
        float4 val = (float4)(@src[0], @src[1], @src[2], @src[3]);
        float4 ringid = 0;
        // TODO: consider switching to vector functions, which might be faster
        for(int i = 0; i < @src.channels; i++){
            if(cycles>0){
                ringid[i] = rint((val[i]*cycles/2)+cycles_phase-0.5);
                val[i] = mx_Cycle(val[i],cycles,cycles_phase,smooth_cycles);
            }
            if(lowclip > 0 || highclip < 1){
                val[i] = mx_Clip(val[i],lowclip,highclip);
            }
            if(brightness != 0){
                val[i] = mx_Brightness(val[i],brightness);
            }
            if(contrast != 0){
                val[i] = mx_Contrast(val[i],contrast);
            }
        }
        @dst.set(val);
        @ringid.set(ringid);
    #endif
}