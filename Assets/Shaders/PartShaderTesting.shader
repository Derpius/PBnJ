Shader "PartShaderTesting"
{
	Properties
	{
		_Colour ("Color", Color) = (1, 1, 1, 1)
		_MetallicColour ("Colour for bare metal surfaces", Color) = (0.6, 0.6, 0.6, 1)

		_DetailStrength ("Detail strength", Range(0, 2.5)) = 1
		_OcclusionStrength ("Occlusion strength", Range(0, 1)) = 1

		_BaseMetalness ("Base metalness", Range(0, 1)) = 0
		_BaseSmoothness ("Base smoothness", Range(0, 1)) = 0

		_DetailTexture ("Detail Texture", 2D) = "" {}
		_NormalMapTexture ("Normal Map Texture", 2D) = "" {}
		_MRAOTexture ("Metalness, roughness, ambient occlusion, mask texture", 2D) = "" {}
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 200

		CGPROGRAM
		#pragma surface surf Standard fullforwardshadows
		#pragma target 3.0

		float4 _Colour;
		float4 _MetallicColour;

		float _DetailStrength;
		float _OcclusionStrength;

		float _BaseMetalness;
		float _BaseSmoothness;

		sampler2D _DetailTexture;
		sampler2D _NormalMapTexture;
		sampler2D _MRAOTexture;

		struct Input
		{
			float2 uv_DetailTexture;
		};

		void surf(Input IN, inout SurfaceOutputStandard o)
		{
			float4 colour = _Colour;
			float2 texcoord = IN.uv_DetailTexture;

			float2 texDetail = tex2D(_DetailTexture, texcoord).rg;
			colour.rgb += (texDetail.r - 0.5019608) * _DetailStrength;
			colour.rgb = saturate(colour.rgb);

			float4 texNormal = tex2D(_NormalMapTexture, texcoord);
			fixed3 localNormal = UnpackNormal(texNormal);
			localNormal.xy *= _DetailStrength;
			localNormal.z += 0.0001;

			float4 metalnessRoughnessAOMask = tex2D(_MRAOTexture, texcoord);
			metalnessRoughnessAOMask = lerp(
				float4(_BaseMetalness, 1.f - _BaseSmoothness, 1.f, 1.f),
				metalnessRoughnessAOMask,
				saturate(_DetailStrength)
			);

			o.Albedo = lerp(_MetallicColour, colour, metalnessRoughnessAOMask.a).rgb;
			o.Normal = localNormal;
			o.Metallic = metalnessRoughnessAOMask.r;
			o.Smoothness = 1.f - metalnessRoughnessAOMask.g;
			o.Occlusion = lerp(1.f, metalnessRoughnessAOMask.b, _OcclusionStrength);
			o.Alpha = 1.f;
		}
		ENDCG
	}
	FallBack "Diffuse"
}
