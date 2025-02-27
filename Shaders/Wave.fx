/*-----------------------------------------------------------------------------------------------------*/
/* Wave Shader - by Radegast Stravinsky of Ultros.                                                */
/* There are plenty of shaders that make your game look amazing. This isn't one of them.               */
/*-----------------------------------------------------------------------------------------------------*/
#include "ReShade.fxh"
#include "Blending.fxh"

#if GSHADE_DITHER
    #include "TriDither.fxh"
#endif

uniform int wave_type <
    ui_type = "combo";
    ui_label = "Wave Type";
    ui_tooltip = "Selects the type of distortion to apply.";
    ui_items = "X/X\0X/Y\0";
    ui_tooltip = "Which axis the distortion should be performed against.";
> = 1;

uniform float angle <
    ui_type = "slider";
    ui_label = "Angle";
    ui_tooltip = "The angle at which the distortion occurs.";
    ui_min = -360.0; 
    ui_max = 360.0; 
    ui_step = 1.0;
> = 0.0;

uniform float period <
    ui_type = "slider";
    ui_label = "Period";
    ui_min = 0.1; 
    ui_max = 10.0;
    ui_tooltip = "The wavelength of the distortion. Smaller values make for a longer wavelength.";
> = 3.0;

uniform float amplitude <
    ui_type = "slider";
    ui_label = "Amplitude";
    ui_min = -1.0; 
    ui_max = 1.0;
    ui_tooltip = "The amplitude of the distortion in each direction.";
> = 0.075;

uniform float phase <
    ui_type = "slider";
    ui_label = "Phase";
    ui_min = -5.0; 
    ui_max = 5.0;
    ui_tooltip = "The offset being applied to the distortion's waves.";
> = 0.0;

uniform float depth_threshold <
    ui_type = "slider";
    ui_label="Depth Threshold";
    ui_category = "Depth";
    ui_min=0.0;
    ui_max=1.0;
> = 0;

uniform int depth_mode <
    ui_type = "combo";
    ui_label = "Depth Mode";
    ui_category = "Depth";
    ui_items = "Minimum\0Maximum\0";
    ui_tooltip = "Mask the effect by using the depth of the scene.";
> = 0;

uniform bool set_max_depth_behind <
    ui_label = "Set Distortion Behind Foreground";
    ui_tooltip = "(Maximum Depth Threshold Mode only) When enabled, sets the distorted area behind the objects that should come in front of it.";
    ui_category = "Depth";
> = 0;


uniform int animate <
    ui_type = "combo";
    ui_label = "Animate";
    ui_items = "No\0Amplitude\0Phase\0Angle\0";
    ui_tooltip = "Enable or disable the animation. Animates the wave effect by phase, amplitude, or angle.";
> = 0;

uniform float anim_rate <
    source = "timer";
>;

BLENDING_COMBO(
    render_type, 
    "Blending Mode", 
    "Blends the effect with the previous layers.",
    "Blending",
    false,
    0,
    0
);

uniform float blending_amount <
    ui_type = "slider";
    ui_label = "Opacity";
    ui_category = "Blending";
    ui_tooltip = "Adjusts the blending amount.";
    ui_min = 0.0;
    ui_max = 1.0;
> = 1.0;

texture texColorBuffer : COLOR;

sampler samplerColor
{
    Texture = texColorBuffer;

    AddressU = MIRROR;
    AddressV = MIRROR;
    AddressW = MIRROR;

    MagFilter = LINEAR;
    MinFilter = LINEAR;
    MipFilter = LINEAR;

    MinLOD = 0.0f;
    MaxLOD = 1000.0f;

    MipLODBias = 0.0f;

    SRGBTexture = false;
};

// Vertex Shader
void FullScreenVS(uint id : SV_VertexID, out float4 position : SV_Position, out float2 texcoord : TEXCOORD0)
{
    if (id == 2)
        texcoord.x = 2.0;
    else
        texcoord.x = 0.0;

    if (id == 1)
        texcoord.y  = 2.0;
    else
        texcoord.y = 0.0;

    position = float4( texcoord * float2(2, -2) + float2(-1, 1), 0, 1);

}

float4 Wave(float4 pos : SV_Position, float2 texcoord : TEXCOORD0) : SV_TARGET 
{
    
    const float ar = 1.0 * (float)BUFFER_HEIGHT / (float)BUFFER_WIDTH;
    const float2 center = float2(0.5 / ar, 0.5);
    const float depth = ReShade::GetLinearizedDepth(texcoord).r;
    float2 tc = texcoord;
    const float4 base = tex2D(samplerColor, texcoord);
    float4 color;

    tc.x /= ar;

    const float theta = radians(animate == 3 ? (anim_rate * 0.01 % 360.0) : angle);
    const float s =  sin(theta);
    const float _s = sin(-theta);
    const float c =  cos(theta);
    const float _c = cos(-theta);

    tc = float2(dot(tc - center, float2(c, -s)), dot(tc - center, float2(s, c)));

    if(wave_type == 0)
    {
        switch(animate)
        {
            default:
                tc.x += amplitude * sin((tc.x * period * 10) + phase);
                break;
            case 1:
                tc.x += (sin(anim_rate * 0.001) * amplitude) * sin((tc.x * period * 10) + phase);
                break;
            case 2:
                tc.x += amplitude * sin((tc.x * period * 10) + (anim_rate * 0.001));
                break;
        }
    }
    else
    {
        switch(animate)
        {
            default:
                tc.x +=  amplitude * sin((tc.y * period * 10) + phase);
                break;
            case 1:
                tc.x += (sin(anim_rate * 0.001) * amplitude) * sin((tc.y * period * 10) + phase);
                break;
            case 2:
                tc.x += amplitude * sin((tc.y * period * 10) + (anim_rate * 0.001));
                break;
        }
    }
    tc = float2(dot(tc, float2(_c, -_s)), dot(tc, float2(_s, _c))) + center;

    tc.x *= ar;

    color = tex2D(samplerColor, tc);
    float blending_factor;
    if(render_type)
        blending_factor = lerp(0, abs(amplitude)* lerp(10, 1, abs(amplitude)), blending_amount);
    else
        blending_factor = blending_amount;
    
    color.rgb = ComHeaders::Blending::Blend(render_type, base.rgb, color.rgb, blending_factor);


    float out_depth;
    bool inDepthBounds;
    if ( depth_mode == 0) {
        out_depth =  ReShade::GetLinearizedDepth(texcoord).r;
        inDepthBounds = out_depth >= depth_threshold;
    } else {
        out_depth = ReShade::GetLinearizedDepth(tc).r;
        inDepthBounds = out_depth <= depth_threshold;
    }

    if(inDepthBounds){
        color = tex2D(samplerColor, tc);
    
        color.rgb = ComHeaders::Blending::Blend(render_type, base.rgb, color.rgb, blending_factor);
    }
    else
    {
        color = tex2D(samplerColor, texcoord);
    }

    if(set_max_depth_behind) {
        const float mask_front = ReShade::GetLinearizedDepth(texcoord).r;
        if(mask_front < depth_threshold)
            color = tex2D(samplerColor, texcoord);
    }
    return color;
}

technique Wave
{
    pass p0
    {
        VertexShader = FullScreenVS;
        PixelShader = Wave;
    }
}
