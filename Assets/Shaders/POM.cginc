#ifndef POM_INCLUDED
#define POM_INCLUDED

#if defined(SHADER_API_D3D11) || defined(SHADER_API_D3D11_9X) || defined(SHADER_API_XBOXONE) || defined(SHADER_API_GLES3) || defined(SHADER_API_GLCORE)
	#define UNITY_SAMPLE_TEX2DARRAY_GRAD(tex,coord,dx,dy) tex.SampleGrad (sampler##tex,coord,dx,dy)
#else
	#if defined(UNITY_COMPILER_HLSL2GLSL) || defined(SHADER_TARGET_SURFACE_ANALYSIS)
		#define UNITY_SAMPLE_TEX2DARRAY_GRAD(tex,coord,dx,dy) texCUBE(sampler##tex,coord,float3(dx,0),float3(dy,0))
	#endif
#endif

void ParallaxOcclusionMapping(
	#ifdef PARALLAX_HEIGHT_TEXTURE_ARRAY
	in float textureArrayIndex,
	#else
	in sampler2D heightMap,
	#endif

	in float heightScale,
	in float minSamples, in float maxSamples,
	in float3 tangentViewDir,
	inout float2 texcoord
) {
	float2 parallaxDirection = normalize(tangentViewDir.xy);
	float viewDirLength = length(tangentViewDir);
	float parallaxLength = sqrt(viewDirLength * viewDirLength - tangentViewDir.z * tangentViewDir.z) / tangentViewDir.z;
	float2 parallaxOffsetTS = parallaxDirection * parallaxLength * heightScale;   

	int numSamples = (int)(lerp(maxSamples, minSamples, abs(dot(float3(0, 0, 1), tangentViewDir))));
	float stepSize = 1.0 / (float)numSamples;

	float currHeight = 0.f;
	float prevHeight = 1.f;
	float currentBound = 1.f;

	float2 dx = ddx(texcoord);
	float2 dy = ddy(texcoord);

	float2 pt1 = 0.f;
	float2 pt2 = 0.f;

	float2 texCurrentOffset = texcoord;
	float2 texOffsetPerStep = stepSize * parallaxOffsetTS;

	bool hit = false;	
	for (int stepIndex = 0; stepIndex < numSamples && !hit; stepIndex++) {
		texCurrentOffset -= texOffsetPerStep;

		#ifdef PARALLAX_HEIGHT_TEXTURE_ARRAY
		currHeight = UNITY_SAMPLE_TEX2DARRAY_GRAD(PARALLAX_HEIGHT_TEXTURE_ARRAY, float3(texCurrentOffset, textureArrayIndex), dx, dy).b;
		#else
		currHeight = tex2Dgrad(heightMap, texCurrentOffset, dx, dy).b;
		#endif

		currentBound -= stepSize;

		if (currHeight > currentBound) {   
			pt1 = float2(currentBound, currHeight);
			pt2 = float2(currentBound + stepSize, prevHeight);
			prevHeight = currHeight;
			hit = true;
		} else {
			prevHeight = currHeight;
		}
	}

	float delta2 = pt2.x - pt2.y;
	float delta1 = pt1.x - pt1.y;  
	float denominator = delta2 - delta1;
	float parallaxAmount = denominator == 0.f ?
		0.f :
		(pt1.x * delta2 - pt2.x * delta1 ) / denominator;

	texcoord -= parallaxOffsetTS * (1 - parallaxAmount);
}

#endif