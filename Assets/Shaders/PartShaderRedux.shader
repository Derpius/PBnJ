Shader "PartShaderRedux"
{
    Properties
    {
        [Space(20)] [Header(Base Pass Config)]
		[Enum(UnityEngine.Rendering.BlendMode)] _BaseBlendModeSource ("_BaseBlendModeSource", Float) = 1
        [Enum(UnityEngine.Rendering.BlendMode)] _BaseBlendModeDestination ("_BaseBlendModeDestination", Float) = 0
        [Enum(Off,0,On,1)] _BaseZWrite ("ZWrite", Float) = 1

        [Space(20)] [Header(Forward Pass Config)]
		[Enum(UnityEngine.Rendering.BlendMode)] _ForwardBlendModeSource ("_ForwardBlendModeSource", Float) = 1
        [Enum(UnityEngine.Rendering.BlendMode)] _ForwardBlendModeDestination ("_ForwardBlendModeDestination", Float) = 1
        [Enum(Off,0,On,1)] _ForwardZWrite ("ZWrite", Float) = 0

        [Space(20)] [Header(Textures)]
		_DetailTextures ("Detail Textures", 2DArray) = "" {}
        _NormalMapTextures ("Normal Maps Textures", 2DArray) = "" {}
        _DecalTexture ("Decal Texture", 2D) = "black" {}
        _DecalTextureMaterialIds ("Decal Materials", Vector) = (0,0,1,1)
        _UseDecalTexture ("Use Decal Texture", Float) = 0

        [Space(20)] [Header(Texture Options)]
		[KeywordEnum(OFF, ON)] DETAIL_TEXTURES ("Detail Textures", Float) = 0
        [KeywordEnum(OFF, ON)] NORMAL_MAPS ("Normal Maps", Float) = 0

        [Space(20)] [Header(Scene Variant)]
		[KeywordEnum(OTHER, FLIGHT)] SCENE ("Scene", Float) = 0

        [Space(20)] [Header(Rim Shading Options)]
		[KeywordEnum(OFF, ON)] RIMSHADE ("Rim Shading", Float) = 0
        _Color ("Color", Vector) = (1,1,1,1)
        _MinPower ("Min Power", Range(0, 1)) = 0.1
        _MaxPower ("Max Power", Range(0, 1)) = 1

        [Space(20)] [Header(Atmosphere Options)]
		[KeywordEnum(None, LOW, HIGH)] OBJECT_ATMOSPHERE ("Atmosphere Quality", Float) = 0

        [Space(20)] [Header(Mask Render)]
		_ReentryMaskBaseStrength ("Reentry Mask Base Strength", Range(0, 10)) = 2
        _ReentryMaskWrapAmount ("Reentry Mask WrapAmount", Range(-1, 0)) = -1
        _VaporMaskBaseStrength ("Vapor Mask Base Strength", Range(0, 10)) = 1
        _VaporMaskWrapAmount ("Vapor Mask WrapAmount", Range(-1, 0)) = -0.2
        _MainTex ("Main Texture (Unused)", 2D) = "black" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 200

        CGPROGRAM
        #pragma surface surf Standard fullforwardshadows vertex:vert
        #pragma target 3.0

        UNITY_DECLARE_TEX2DARRAY(_DetailTextures);
        UNITY_DECLARE_TEX2DARRAY(_NormalMapTextures);

		fixed4 SampleTexArray(UNITY_ARGS_TEX2DARRAY(_TexArray), float2 uv, float index) {
			return UNITY_SAMPLE_TEX2DARRAY(_TexArray, float3(uv, index));
		}

		float4 _Color;
		float4 _MaterialColors[50];
		float4 _MaterialData[50];

        struct Input
        {
            float2 uv_DetailTextures;
			float2 uv_NormalMapTextures;
			float detailIdx;
			float normalIdx;
        };

		void vert(inout appdata_full v, out Input o) {
			UNITY_INITIALIZE_OUTPUT(Input, o);

			o.detailIdx = floor(v.texcoord.z);
			o.normalIdx = floor(v.texcoord.w);
		}

        void surf(Input IN, inout SurfaceOutputStandard o)
        {
            fixed4 detailColour = SampleTexArray(UNITY_PASS_TEX2DARRAY(_DetailTextures), IN.uv_DetailTextures, IN.detailIdx);
			fixed4 normalColour = SampleTexArray(UNITY_PASS_TEX2DARRAY(_NormalMapTextures), IN.uv_NormalMapTextures, IN.normalIdx);

            o.Albedo = float3(IN.detailIdx / 5.f, 1.f, 1.f);//detailColour.rgb * _Color.rgb;
			o.Normal = normalColour.rgb;
            o.Metallic = 0.f;
            o.Smoothness = 0.f;
            o.Alpha = 1.f;
        }
        ENDCG
    }
    FallBack "Diffuse"
}
