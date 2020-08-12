precision highp float;

uniform sampler2D texture;
varying vec2 textureCoordsVarying;

const vec2 texSize = vec2(400.0, 400.0);
const vec2 mosaicSize = vec2(16.0, 16.0);

void main() {
    vec2 intXY = vec2(textureCoordsVarying.x * texSize.x, textureCoordsVarying.y * texSize.y);
    vec2 XYMosaic = vec2(floor(intXY.x/mosaicSize.x) * mosaicSize.x, floor(intXY.y/mosaicSize.y) * mosaicSize.y);
    vec2 uvMosaic = vec2(XYMosaic.x/texSize.x, XYMosaic.y/texSize.y);
    
    gl_FragColor = texture2D(texture, uvMosaic);
}
