//
//  ViewController.m
//  OpenGL_ES_Filter_02
//
//  Created by tlab on 2020/8/12.
//  Copyright © 2020 yuanfangzhuye. All rights reserved.
//

#import "ViewController.h"
#import <GLKit/GLKit.h>
#import "FilterBar.h"

typedef struct {
    GLKVector3 positionCoord; // (X, Y, Z)
    GLKVector2 textureCoord; // (U, V)
} SenceVertex;

@interface ViewController ()<FilterBarDelegate>

@property (nonatomic, strong) EAGLContext *myContext;
@property (nonatomic, strong) CADisplayLink *displayLink; //用于刷新屏幕

@property (nonatomic, assign) SenceVertex *vertexs;
@property (nonatomic, assign) NSTimeInterval startTimeInterval; //开始的时间戳
@property (nonatomic, assign) GLuint program; //着色器程序
@property (nonatomic, assign) GLuint vertexBuffer; //顶点缓存
@property (nonatomic, assign) GLuint textureID; //纹理 ID

@end

@implementation ViewController

- (void)dealloc {
    //1.释放上下文
    if ([EAGLContext currentContext] == self.myContext) {
        [EAGLContext setCurrentContext:nil];
    }
    
    //2.顶点缓存区释放
    if (_vertexBuffer) {
        glDeleteBuffers(1, &_vertexBuffer);
        _vertexBuffer = 0;
    }
    
    //3.顶点数组释放
    if (_vertexs) {
        free(_vertexs);
        _vertexs = nil;
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    //移除 displayLink
    if (self.displayLink) {
        [self.displayLink invalidate];
        self.displayLink = nil;
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    //设置背景颜色
    self.view.backgroundColor = [UIColor blackColor];
    //创建滤镜工具栏
    [self setupFilterBar];
    //滤镜处理初始化
    [self filterInit];
    //开始一个滤镜动画
    [self startFilterAnimation];
}


// 创建滤镜栏
- (void)setupFilterBar {
    CGFloat filterBarWidth = [UIScreen mainScreen].bounds.size.width;
    CGFloat filterBarHeight = 100;
    CGFloat filterBarY = [UIScreen mainScreen].bounds.size.height - filterBarHeight;
    
    FilterBar *filterBar = [[FilterBar alloc] initWithFrame:CGRectMake(0, filterBarY, filterBarWidth, 100)];
    filterBar.delegate = self;
    [self.view addSubview:filterBar];
    
    NSArray *dataSource = @[@"无",@"灰度",@"颠倒",@"马赛克",@"马赛克2",@"马赛克3"];
    filterBar.itemList = dataSource;
}


- (void)filterInit {
    //1.创建上下文并设置当前上下文
    self.myContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    [EAGLContext setCurrentContext:self.myContext];
    
    //2.开辟顶点数组内存空间
    self.vertexs = malloc(sizeof(SenceVertex) * 4);
    
    //3.初始化顶点（0，1，2，3）的顶点坐标&纹理坐标
    self.vertexs[0] = (SenceVertex){{-1, 1, 0}, {0, 1}};
    self.vertexs[1] = (SenceVertex){{-1, -1, 0}, {0, 0}};
    self.vertexs[2] = (SenceVertex){{1, 1, 0}, {1, 1}};
    self.vertexs[3] = (SenceVertex){{1, -1, 0}, {1, 0}};
    
    //4.创建图层（CAEAGLLayer）
    CAEAGLLayer *myLayer = [[CAEAGLLayer alloc] init];
    //设置图层frame
    myLayer.frame = CGRectMake(0, 100, self.view.frame.size.width, self.view.frame.size.width);
    //设置图层的scale
    myLayer.contentsScale = [UIScreen mainScreen].scale;
    //给View添加layer
    [self.view.layer addSublayer:myLayer];
    
    //5.绑定渲染缓存区
    [self bindRenderLayer:myLayer];
    
    //6.获取处理的图片路径
    NSString *imagePath = [[NSBundle mainBundle] pathForResource:@"xiaochen" ofType:@"png"];
    //读取图片
    UIImage *localImage = [UIImage imageWithContentsOfFile:imagePath];
    //将图片转换为纹理图片
    GLuint textureID = [self createTextureWithImage:localImage];
    //设置纹理ID
    self.textureID = textureID; //将纹理 ID 保存，方便后面切换滤镜的时候重用
    
    //7.设置视口
    glViewport(0, 0, self.drawableWidth, self.drawableHeight);
    
    //8.设置顶点缓存区
    GLuint vertexBuffer;
    glGenBuffers(1, &vertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
    GLsizeiptr bufferSizeBytes = sizeof(SenceVertex) * 4;
    glBufferData(GL_ARRAY_BUFFER, bufferSizeBytes, self.vertexs, GL_STATIC_DRAW);
    
    //9.设置默认着色器
    [self setupShaderProgramWithName:@"Normal"];
    
    //10.将顶点缓存保存，退出时才释放
    self.vertexBuffer = vertexBuffer;
}


- (void)bindRenderLayer:(CAEAGLLayer *)eaglLayer {
    
    //1.渲染缓存区,帧缓存区对象
    GLuint renderBuffer;
    GLuint frameBuffer;
    
    //2.获取渲染缓存区名称,绑定渲染缓存区以及将渲染缓存区与layer建立连接
    glGenRenderbuffers(1, &renderBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, renderBuffer);
    [self.myContext renderbufferStorage:GL_RENDERBUFFER fromDrawable:eaglLayer];
    
    //3.获取帧缓存区名称,绑定帧缓存区以及将渲染缓存区附着到帧缓存区上
    glGenFramebuffers(1, &frameBuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, frameBuffer);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, renderBuffer);
}


- (GLuint)createTextureWithImage:(UIImage *)image {
    
    //1.将 UIImage 转换为 CGImageRef
    CGImageRef cgImageRef = [image CGImage];
    //判断图片是否获取成功
    if (!cgImageRef) {
        NSLog(@"Failed to load image");
        exit(1);
    }
    
    //2.读取图片的大小、宽高
    GLuint imageWidth = (GLuint)CGImageGetWidth(cgImageRef);
    GLuint imageHeight = (GLuint)CGImageGetHeight(cgImageRef);
    
    //获取图片的rect
    CGRect imageRect = CGRectMake(0, 0, imageWidth, imageHeight);
    
    //获取图片的颜色空间
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    //3.获取图片的字节数
    void *imageDatas = malloc(imageWidth * imageHeight * 4);
    
    //4.创建上下文
    /*
    参数1：data,指向要渲染的绘制图像的内存地址
    参数2：width,bitmap的宽度，单位为像素
    参数3：height,bitmap的高度，单位为像素
    参数4：bitPerComponent,内存中像素的每个组件的位数，比如32位RGBA，就设置为8
    参数5：bytesPerRow,bitmap的没一行的内存所占的比特数
    参数6：colorSpace,bitmap上使用的颜色空间  kCGImageAlphaPremultipliedLast：RGBA
    */
    CGContextRef context = CGBitmapContextCreate(imageDatas, imageWidth, imageHeight, 8, imageWidth * 4, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    
    //5.图片翻转(图片默认是倒置的)
    CGContextTranslateCTM(context, 0, imageHeight);
    CGContextScaleCTM(context, 1.0, -1.0);
    CGColorSpaceRelease(colorSpace);
    CGContextClearRect(context, imageRect);
    
    //对图片进行重新绘制，得到一张新的解压缩后的位图
    CGContextDrawImage(context, imageRect, cgImageRef);
    
    //6.获取纹理ID、设置图片纹理属性
    GLuint textureID;
    glGenTextures(1, &textureID);
    glBindTexture(GL_TEXTURE_2D, textureID);
    
    //7.载入纹理 2D 数据
    /*
    参数1：纹理模式，GL_TEXTURE_1D、GL_TEXTURE_2D、GL_TEXTURE_3D
    参数2：加载的层次，一般设置为0
    参数3：纹理的颜色值GL_RGBA
    参数4：宽
    参数5：高
    参数6：border，边界宽度
    参数7：format
    参数8：type
    参数9：纹理数据
    */
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, imageWidth, imageHeight, 0, GL_RGBA, GL_UNSIGNED_BYTE, imageDatas);
    
    //8.设置纹理属性
    //环绕方式
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    //过滤方式
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    
    //9.绑定纹理
    /*
    参数1：纹理维度
    参数2：纹理ID,因为只有一个纹理，给0就可以了。
    */
    glBindTexture(GL_TEXTURE_2D, 0);
    
    CGContextRelease(context);
    free(imageDatas);
    
    return textureID;
}


// 开始一个滤镜动画
- (void)startFilterAnimation {
    //1.判断 displayLink 是否为空
    if (self.displayLink) {
        [self.displayLink invalidate];
        self.displayLink = nil;
    }
    
    //2.设置 displayLink 的方法
    self.startTimeInterval = 0;
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayClick)];
    
    //3.将 displaylink 添加到 runloop 运行循环中
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}


- (void)displayClick {
    if (self.startTimeInterval == 0) {
        self.startTimeInterval = self.displayLink.timestamp;
    }
    
    //使用 program
    glUseProgram(self.program);
    //绑定 buffer
    glBindBuffer(GL_ARRAY_BUFFER, self.vertexBuffer);
    
    //传入时间
    CGFloat currentTime = self.displayLink.timestamp - self.startTimeInterval;
    GLuint time = glGetUniformLocation(self.program, "Time");
    glUniform1f(time, currentTime);
    
    //清除画布
    glClear(GL_COLOR_BUFFER_BIT);
    glClearColor(1, 1, 1, 1);
    
    //重绘
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    //渲染到屏幕上
    [self.myContext presentRenderbuffer:GL_RENDERBUFFER];
}


#pragma mark ------ FilterBarDelegate

- (void)filterBar:(FilterBar *)filterBar didScrollToIndex:(NSUInteger)index {
    if (index == 0) {
        //普通图片显示着色器程序
        [self setupShaderProgramWithName:@"Normal"];
    }
    else if (index == 1) {
        // 灰度滤镜着色器程序
        [self setupShaderProgramWithName:@"Gray"];
    }
    else if (index == 2) {
        // 颠倒滤镜着色器程序
        [self setupShaderProgramWithName:@"Reversal"];
    }
    else if (index == 3) {
        // 矩形马赛克滤镜着色器程序
        [self setupShaderProgramWithName:@"Mosaic"];
    }
    else if (index == 4) {
        // 六边形马赛克滤镜着色器程序
        [self setupShaderProgramWithName:@"HexagonMosaic"];
    }
    else if (index == 5) {
        // 三角形马赛克滤镜着色器程序
        [self setupShaderProgramWithName:@"TriangularMosaic"];
    }
    
    // 重新开始滤镜动画
    [self startFilterAnimation];
}


// 初始化着色器程序
- (void)setupShaderProgramWithName:(NSString *)name {
    
    //1.获取着色器program
    GLuint program = [self programWithShaderName:name];
    
    //2.use program
    glUseProgram(program);
    
    //3.获取Position,Texture,TextureCoords 的索引位置
    GLuint positionSlot = glGetAttribLocation(program, "position");
    GLuint textureSlot = glGetUniformLocation(program, "texture");
    GLuint textureCoordSlot = glGetAttribLocation(program, "textureCoords");
    
    //4.激活纹理，绑定纹理ID
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, self.textureID);
    
    //5.纹理采样器
    glUniform1i(textureSlot, 0);
    
    //6.打开positionSlot 属性并且传递数据到positionSlot中(顶点坐标)
    glEnableVertexAttribArray(positionSlot);
    glVertexAttribPointer(positionSlot, 3, GL_FLOAT, GL_FALSE, sizeof(SenceVertex), NULL + offsetof(SenceVertex, positionCoord));
    
    //7.打开textureCoordsSlot 属性并传递数据到textureCoordsSlot(纹理坐标)
    glEnableVertexAttribArray(textureCoordSlot);
    glVertexAttribPointer(textureCoordSlot, 2, GL_FLOAT, GL_FALSE, sizeof(SenceVertex), NULL + offsetof(SenceVertex, textureCoord));
    
    //8.保存program,界面销毁则释放
    self.program = program;
}


//link program
- (GLuint)programWithShaderName:(NSString *)shadername {
    
    //1. 编译顶点着色器/片元着色器
    GLuint vertexShader = [self compileShaderWithName:shadername type:GL_VERTEX_SHADER];
    GLuint fragShader = [self compileShaderWithName:shadername type:GL_FRAGMENT_SHADER];
    
    //2. 将顶点/片元附着到program
    GLuint program = glCreateProgram();
    glAttachShader(program, vertexShader);
    glAttachShader(program, fragShader);
    
    //3.linkProgram
    glLinkProgram(program);
    
    //4.检查是否link成功
    GLint linkSuccess;
    glGetProgramiv(program, GL_LINK_STATUS, &linkSuccess);
    if (linkSuccess == GL_FALSE) {
        GLchar messages[256];
        glGetProgramInfoLog(program, sizeof(messages), 0, &messages[0]);
        NSString *messageString = [NSString stringWithUTF8String:messages];
        NSAssert(NO, @"program链接失败：%@", messageString);
        exit(1);
    }
    
    //5.返回program
    return program;
}


//编译shader代码
- (GLuint)compileShaderWithName:(NSString *)shadername type:(GLenum)shaderType {
    
    //1.获取 shader 路径
    NSString *shaderPath = [[NSBundle mainBundle] pathForResource:shadername ofType:shaderType == GL_VERTEX_SHADER ? @"vsh" : @"fsh"];
    NSError *error;
    NSString *shaderString = [NSString stringWithContentsOfFile:shaderPath encoding:NSUTF8StringEncoding error:&error];
    if (!shaderString) {
        NSAssert(NO, @"读取shader失败");
        exit(1);
    }
    
    //2. 创建shader->根据shaderType
    GLuint shader = glCreateShader(shaderType);
    
    //3.获取 shader source
    const char *shaderStringUTF8 = [shaderString UTF8String];
    int shaderStringLength = (int)[shaderString length];
    glShaderSource(shader, 1, &shaderStringUTF8, &shaderStringLength);
    
    //4.编译shader
    glCompileShader(shader);
    
    //5.查看编译是否成功
    GLint compileSuccess;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &compileSuccess);
    if (compileSuccess == GL_FALSE) {
        GLchar messages[256];
        glGetShaderInfoLog(shader, sizeof(messages), 0, &messages[0]);
        NSString *messageString = [NSString stringWithUTF8String:messages];
        NSAssert(NO, @"shader编译失败：%@", messageString);
        exit(1);
    }
    
    //6.返回shader
    return shader;
}


//获取渲染缓存区的宽
- (GLint)drawableWidth {
    GLint backingWidth;
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &backingWidth);
    return backingWidth;
}


//获取渲染缓存区的高
- (GLint)drawableHeight {
    GLint backingHeight;
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &backingHeight);
    return backingHeight;
}


@end
