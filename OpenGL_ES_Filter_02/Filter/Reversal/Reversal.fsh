precision highp float;

uniform sampler2D texture;
varying vec2 textureCoordsVarying;

void main() {
    vec4 mask = texture2D(texture, vec2(textureCoordsVarying.x, 1.0 - textureCoordsVarying.y));
    gl_FragColor = mask;
}
