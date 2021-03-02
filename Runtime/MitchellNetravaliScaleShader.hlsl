// Mitchell-Netravali ��ֵ�㷨
// ��ֲ�� https://github.com/libretro/common-shaders/blob/master/bicubic/shaders/bicubic-normal.cg


cbuffer constants : register(b0) {
	int2 srcSize : packoffset(c0.x);
	int2 destSize : packoffset(c0.z);
	int useSharperVersion : packoffset(c1.x);
};


#define D2D_INPUT_COUNT 1
#define D2D_INPUT0_COMPLEX
#define MAGPIE_USE_SAMPLE_INPUT
#include "common.hlsli"


float weight(float x, float B, float C) {
	float ax = abs(x);

	if (ax < 1.0) {
		return (pow(x, 2.0) * ((12.0 - 9.0 * B - 6.0 * C) * ax + (-18.0 + 12.0 * B + 6.0 * C)) + (6.0 - 2.0 * B)) / 6.0;
	} else if (ax >= 1.0 && ax < 2.0) {
		return (pow(x, 2.0) * ((-B - 6.0 * C) * ax + (6.0 * B + 30.0 * C)) + (-12.0 * B - 48.0 * C) * ax + (8.0 * B + 24.0 * C)) / 6.0;
	} else {
		return 0.0;
	}
}

float4 weight4(float x) {
	float B = 0.0;
	float C = 0.0;
	if (useSharperVersion == 0) {
		// Mitchel-Netravali coefficients.
		// Best psychovisual result.
		B = 1.0 / 3.0;
		C = 1.0 / 3.0;
	} else {
		// Sharper version.
		// May look better in some cases.
		B = 0.0;
		C = 0.75;
	}

	return float4(
		weight(x - 2.0, B, C),
		weight(x - 1.0, B, C),
		weight(x, B, C),
		weight(x + 1.0, B, C)
	);
}


float3 line_run(float ypos, float4 xpos, float4 linetaps) {
	return SampleInputNoCheck(0, float2(xpos.r, ypos)) * linetaps.r
		+ SampleInputNoCheck(0, float2(xpos.g, ypos)) * linetaps.g
		+ SampleInputNoCheck(0, float2(xpos.b, ypos)) * linetaps.b
		+ SampleInputNoCheck(0, float2(xpos.a, ypos)) * linetaps.a;
}


D2D_PS_ENTRY(main) {
	InitMagpieSampleInputWithScale(float2(destSize) / srcSize);

	float2 f = frac(coord.xy / coord.zw + 0.5);
	
	float4 linetaps = weight4(1.0 - f.x);
	float4 columntaps = weight4(1.0 - f.y);

	//make sure all taps added together is exactly 1.0, otherwise some (very small) distortion can occur
	linetaps /= linetaps.r + linetaps.g + linetaps.b + linetaps.a;
	columntaps /= columntaps.r + columntaps.g + columntaps.b + columntaps.a;

	// !!!�ı䵱ǰ����
	coord.xy -= (f + 1) * coord.zw;

	float4 xpos = float4(coord.x, GetCheckedRight(1), GetCheckedRight(2), GetCheckedRight(3));

	// final sum and weight normalization
	return float4(line_run(coord.y, xpos, linetaps) * columntaps.r
		+ line_run(GetCheckedBottom(1), xpos, linetaps) * columntaps.g
		+ line_run(GetCheckedBottom(2), xpos, linetaps) * columntaps.b
		+ line_run(GetCheckedBottom(3), xpos, linetaps) * columntaps.a,
		1);
}