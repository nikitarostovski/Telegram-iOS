#include <metal_stdlib>
using namespace metal;


#pragma mark - Types

struct RadialUniforms {
    float3 color1;
    float3 color2;
    float3 color3;
    float3 color4;
    
    float2 pos1;
    float2 pos2;
    float2 pos3;
    float2 pos4;
};


#pragma mark - Constants stuff

constant float radius = 0.05; // 0.05;


#pragma mark - Color mixing stuff

METAL_FUNC float3 rgb2yuv(float3 color) {
//    return color;
    float y =  0.299 * color.r + 0.587 * color.g + 0.114 * color.b;
    float u = -0.147 * color.r - 0.289 * color.g + 0.436 * color.b;
    float v =  0.615 * color.r - 0.515 * color.g - 0.100 * color.b;
    return float3(y, u, v);
}

METAL_FUNC float3 yuv2rgb(float3 color) {
//    return color;
    float y = color.r; float u = color.g; float v = color.b;
    float r = y + 1.14 * v;
    float g = y - 0.39 * u - 0.58 * v;
    float b = y + 2.03 * u;
    return float3(r, g, b);
}

METAL_FUNC float3 make_color(float3 color1,
                  float3 color2,
                  float3 color3,
                  float3 color4,
                  
                  float2 pos1,
                  float2 pos2,
                  float2 pos3,
                  float2 pos4,
                  
                  float2 position) {
    
    
    float dist1 = distance(pos1, position) - radius;
    float dist2 = distance(pos2, position) - radius;
    float dist3 = distance(pos3, position) - radius;
    float dist4 = distance(pos4, position) - radius;
    
//    if (dist1 <= 0) {
//        return color1;
//    } else if (dist2 <= 0) {
//        return color2;
//    } else if (dist3 <= 0) {
//        return color3;
//    } else if (dist4 <= 0) {
//        return color4;
//    }
//
//    if (min(min(dist1, dist2), min(dist3, dist4)) > 0.1) {
//        return float3(0, 0, 0);
//    }
    
    color1 = rgb2yuv(color1);
    color2 = rgb2yuv(color2);
    color3 = rgb2yuv(color3);
    color4 = rgb2yuv(color4);
    
    float viewDistance = 0.3;
    
    float p1 = abs(viewDistance - dist1);
    float p2 = abs(viewDistance - dist2);
    float p3 = abs(viewDistance - dist3);
    float p4 = abs(viewDistance - dist4);

    float pTotal = p1 + p2 + p3 + p4;

    float percentage1 = p1 / pTotal;
    float percentage2 = p2 / pTotal;
    float percentage3 = p3 / pTotal;
    float percentage4 = p4 / pTotal;
    
    
    
    
    float r1 = color1.r * percentage1;
    float g1 = color1.g * percentage1;
    float b1 = color1.b * percentage1;
    
    float r2 = color2.r * percentage2;
    float g2 = color2.g * percentage2;
    float b2 = color2.b * percentage2;
    
    float r3 = color3.r * percentage3;
    float g3 = color3.g * percentage3;
    float b3 = color3.b * percentage3;
    
    float r4 = color4.r * percentage4;
    float g4 = color4.g * percentage4;
    float b4 = color4.b * percentage4;
    
    
    float3 result = float3(r1 + r2 + r3 + r4,
                           g1 + g2 + g3 + g4,
                           b1 + b2 + b3 + b4);
    
    return yuv2rgb(result);
}


#pragma mark - Coordinates stuff

METAL_FUNC float2 fix_aspect_ratio(float2 coordinate, float aspect_ratio) {
    coordinate -= float2(0.5, 0.5);
    coordinate /= float2(1.0, aspect_ratio);
    coordinate += float2(0.5, 0.5);
    return coordinate;
}


#pragma mark - Blur stuff

METAL_FUNC half gauss(half x, half sigma) {
    return 1 / sqrt(2 * M_PI_H * sigma * sigma) * exp(-x * x / (2 * sigma * sigma));
};


#pragma mark - Kernel stuff

kernel void radial(constant RadialUniforms *uniforms [[buffer(0)]],
                  texture2d<float, access::write> texture [[ texture(0) ]],
                  uint2 gid [[ thread_position_in_grid ]])
{

    if (gid.x >= texture.get_width() || gid.y >= texture.get_height()) {
        return;
    }
    
    const float2 dimensions = float2(texture.get_width(), texture.get_height());
    const float aspect_ratio = dimensions.x / dimensions.y;

    const float2 coordinate = fix_aspect_ratio(float2(gid) / dimensions, aspect_ratio);
    
    
    const float3 color1 = uniforms->color1;
    const float3 color2 = uniforms->color2;
    const float3 color3 = uniforms->color3;
    const float3 color4 = uniforms->color4;
    const float2 pos1 = fix_aspect_ratio(uniforms->pos1, aspect_ratio);
    const float2 pos2 = fix_aspect_ratio(uniforms->pos2, aspect_ratio);
    const float2 pos3 = fix_aspect_ratio(uniforms->pos3, aspect_ratio);
    const float2 pos4 = fix_aspect_ratio(uniforms->pos4, aspect_ratio);
    
    const float3 c = make_color(color1, color2, color3, color4, pos1, pos2, pos3, pos4, coordinate);
    const float4 result_color = float4(c.r, c.g, c.b, 1);
    
    texture.write(result_color, gid);
    
//    if (gid.x % 20 < 10) {
//        texture.write(float4(1, 0, 0, 1), gid);
//        return;
//    }
}

kernel void blur(texture2d<float, access::read> inTexture [[ texture(0) ]],
                 texture2d<float, access::write> outTexture [[ texture(1) ]],
                 uint2 gid [[ thread_position_in_grid ]]) {

//    if (gid.x % 20 < 5) {
//        outTexture.write(float4(0, 0, 0, 1), gid);
//    }



    constexpr int kernel_size = 7;
    constexpr int radius = kernel_size / 2;

    const float sigma = 50.2;

    float kernel_weight = 0;
    for (int j = 0; j <= kernel_size - 1; j++) {
        for (int i = 0; i <= kernel_size - 1; i++) {
            int2 normalized_position(i - radius, j - radius);
            kernel_weight += gauss(normalized_position.x, sigma) * gauss(normalized_position.y, sigma);
        }
    }

    float4 acc_color(0, 0, 0, 0);
    for (int j = 0; j <= kernel_size - 1; j++) {
        for (int i = 0; i <= kernel_size - 1; i++) {
            int2 normalized_position(i - radius, j - radius);
            uint2 texture_index(gid.x + (i - radius), gid.y + (j - radius));
            float factor = gauss(normalized_position.x, sigma) * gauss(normalized_position.y, sigma) / kernel_weight;
            acc_color += factor * inTexture.read(texture_index).rgba;
        }
    }

    outTexture.write(acc_color, gid);
}



kernel void swirl(texture2d<float, access::read> inTexture [[ texture(0) ]],
                                    texture2d<float, access::read> inTexture2 [[ texture(1) ]],
                                    texture2d<float, access::write> outTexture [[ texture(2) ]],
//                                    texture2d<float, access::read> samplerTex [[ texture(3) ]],
                                    device const float *progress [[ buffer(0) ]],
                                    uint2 gid [[ thread_position_in_grid ]])
{
//    constexpr sampler displacementMap;
//    float strength = 0.0005;
//
//    float2 ngid = float2(gid);
//    float prog = *progress;
//    ngid.x /= inTexture.get_width();
//    ngid.y /= inTexture.get_height();
//
//    float4 orig = inTexture.read(gid);
//    float4 secOrig = inTexture2.read(gid);
//
//    float displacement = secOrig.r * strength;
//
//    float2 newFrom = float2(ngid.x + prog * displacement, ngid.y);
//    newFrom.x *= inTexture.get_width();
//    newFrom.y *= inTexture.get_height();
//
//    float2 newTo = float2(ngid.x - (1.0 - prog) * displacement, ngid.y);
//    newTo.x *= inTexture.get_width();
//    newTo.y *= inTexture.get_height();
//
//    uint2 uvFrom = uint2(newFrom);
//    uint2 uvTo = uint2(newTo);
//
//    outTexture.write(mix(
//                         inTexture2.read(uvTo),
//                         inTexture.read(uvFrom),
//                         prog
//                         ), gid);
}

//kernel void swirl(texture2d<float, access::write> outputTexture [[texture(1)]],
//                        texture2d<float, access::sample> inputTexture [[texture(0)]],
//                        uint2 gid [[thread_position_in_grid]]) {
//
//
//    float2 uv = float2(gid);
//    float iTime = 345;
//
//    uv.x += sin(uv.y * 10.0 + iTime) / 10.0;
//
//    float4 color = inputTexture.read(uint2(uv)).rgba;
//
//    outputTexture.write(color, gid);
//}

//kernel void swirl(texture2d<float, access::write> outputTexture [[texture(1)]],
//                        texture2d<float, access::sample> inputTexture [[texture(0)]],
//                        uint2 gid [[thread_position_in_grid]]) {
//
//    if ((gid.x >= outputTexture.get_width()) || (gid.y >= outputTexture.get_height())) { return; }
//
//    const float2 center = float2(0.5, 0.5);
//    const float radius = 0.2;
//    const float angle = 0.05;
//
//    const float2 dimensions = float2(inputTexture.get_width(), inputTexture.get_height());
//    const float aspect_ratio = dimensions.x / dimensions.y;
//
//    float2 coordinate = fix_aspect_ratio(float2(gid) / dimensions, aspect_ratio);
//
//    const float dist = distance(center, coordinate);
//
//    if (dist < radius) {
//        coordinate -= center;
//        const float percent = (radius - dist) / radius;
//        const float theta = percent * percent * angle * 8.0;
//        const float s = sin(theta);
//        const float c = cos(theta);
//        coordinate = float2(dot(coordinate, float2(c, -s)), dot(coordinate, float2(s, c)));
//        coordinate += center;
//    }
//
//    constexpr sampler quadSampler(mag_filter::linear, min_filter::linear);
//    const float4 outColor = inputTexture.sample(quadSampler, coordinate);
//    outputTexture.write(outColor, gid);
//}

