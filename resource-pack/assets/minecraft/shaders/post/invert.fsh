#version 150

uniform sampler2D InSampler;
uniform float time;
in vec2 texCoord;
out vec4 fragColor;

// rotation
const float YAW_DEGREES   = 0.0;
const float PITCH_DEGREES = 0.0;
const float ROLL_DEGREES  = 0.0;

// bodycam
const float ZOOM           = 1.1;
const float DISTORTION     = 0.025;
const float EDGE_FISHEYE   = 0.15;
const float PIXEL_SIZE     = 2.0;
const float SATURATION     = 0.8;
const float CONTRAST       = 1.2;
const float VIGNETTE_START = 0.5;
const float VIGNETTE_END   = 1.0;
const float CHROMA_OFF     = 0.04;
const float MOTION_SAMPLES = 3.0;
const float MOTION_STRENGTH = 0.005;

// helpers
vec3 adjustSaturation(vec3 color, float sat) {
    float gray = dot(color, vec3(0.299,0.587,0.114));
    return mix(vec3(gray), color, sat);
}
vec3 adjustContrast(vec3 color, float contrast) {
    return (color - 0.5) * contrast + 0.5;
}

void main() {
    // detect resolution
    ivec2 texSize = textureSize(InSampler, 0);
    vec2 resolution = vec2(texSize);

    // fallback
    if (resolution.x <= 0.0 || resolution.y <= 0.0) {
        resolution = vec2(1920.0, 1080.0);
    }

    float pixelSize = PIXEL_SIZE * (resolution.y / 1080.0);

    // rotation pass
    vec2 uv = texCoord;
    vec2 c = uv - vec2(0.5);
    float aspect = (resolution.y <= 0.0) ? 1.0 : (resolution.x / resolution.y);

    // camera space point
    vec3 p = vec3(c.x * aspect, c.y, 1.0);

    // angles to radians
    float yaw   = radians(YAW_DEGREES);
    float pitch = radians(PITCH_DEGREES);
    float roll  = radians(ROLL_DEGREES);

    // rotation matrices
    mat3 rotY = mat3(
         cos(yaw), 0.0,  sin(yaw),
         0.0,      1.0,  0.0,
        -sin(yaw), 0.0,  cos(yaw)
    );

    mat3 rotX = mat3(
        1.0,      0.0,         0.0,
        0.0,  cos(pitch), -sin(pitch),
        0.0,  sin(pitch),  cos(pitch)
    );

    mat3 rotZ = mat3(
        cos(roll), -sin(roll), 0.0,
        sin(roll),  cos(roll), 0.0,
        0.0,         0.0,      1.0
    );

    vec3 rp = rotZ * (rotX * (rotY * p));

    // if behind the camera output black
    if (rp.z <= 0.0) {
        fragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    // project back to 2d and convert to UV coords
    vec2 proj = rp.xy / rp.z;
    vec2 rotatedUV = vec2(proj.x / aspect, proj.y) + vec2(0.5);

    // bodycanm pass
    vec2 inUV = clamp(rotatedUV, 0.0, 1.0);
    vec2 centered = inUV - vec2(0.5);

    // aspect correction and zoom from bodycam
    vec2 pos = centered;
    pos.x *= aspect;
    pos /= ZOOM;

    // fisheye
    float r = length(pos);
    float fisheyeR = r + DISTORTION * r * (1.0 - r);

    // edge based stronger fisheye
    float edgeFactor = smoothstep(VIGNETTE_START, VIGNETTE_END, r);
    fisheyeR += EDGE_FISHEYE * edgeFactor * r;

    vec2 normPos = normalize(pos + vec2(1e-6));
    vec2 fishPos = normPos * fisheyeR;
    vec2 fishUV = 0.5 + vec2(fishPos.x / aspect, fishPos.y);
    fishUV = clamp(fishUV, 0.0, 1.0);

    vec2 pixelUV = floor(fishUV * resolution / pixelSize) * pixelSize / resolution;

    vec2 chroma = normalize(centered + vec2(1e-6)) * CHROMA_OFF * edgeFactor;

    // motion blur
    vec3 blurColor = vec3(0.0);
    vec2 dir = normalize(centered + vec2(1e-6));
    for (int i = 0; i < MOTION_SAMPLES; i++) {
        float t = float(i) / float(MOTION_SAMPLES);
        vec2 offsetUV = pixelUV - dir * MOTION_STRENGTH * t;
        vec4 rC = texture(InSampler, clamp(offsetUV + chroma, 0.0, 1.0));
        vec4 gC = texture(InSampler, clamp(offsetUV, 0.0, 1.0));
        vec4 bC = texture(InSampler, clamp(offsetUV - chroma, 0.0, 1.0));
        blurColor += vec3(rC.r, gC.g, bC.b);
    }
    blurColor /= float(MOTION_SAMPLES);

    vec3 base = mix(vec3(texture(InSampler, clamp(pixelUV, 0.0, 1.0)).rgb), blurColor, 0.6);

    // vignette
    float vign = smoothstep(VIGNETTE_START, VIGNETTE_END, r);
    base *= 1.0 - vign;

    // color adjustments
    base = adjustSaturation(base, SATURATION);
    base = adjustContrast(base, CONTRAST);

    fragColor = vec4(clamp(base, 0.0, 1.0), 1.0);
}