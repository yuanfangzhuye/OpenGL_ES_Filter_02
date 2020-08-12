precision highp float;

uniform sampler2D texture;
varying vec2 textureCoordsVarying;
const highp vec3 w = vec3(0.2125, 0.7154, 0.0721);

void main() {
    vec4 mask = texture2D(texture, textureCoordsVarying);
    float lumiance = dot(mask.rgb, w);
    gl_FragColor = vec4(vec3(lumiance), 1.0);
}
