//
//  ViewController.m
//  IYNAudioExample
//
//  Created by qiyun on 17/1/12.
//  Copyright © 2017年 qiyun. All rights reserved.
//

#import "ViewController.h"
#import "IDYAudioManager.h"

@interface ViewController ()

@property (nonatomic, strong) IDYAudioManager   *audioManager;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    _audioManager = [[IDYAudioManager alloc] init];
    
    _audioManager.stereoPan = 10.0;

}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}





- (void)animtionsWithBezierPath{
    
    CAShapeLayer *shapeLayer = [[CAShapeLayer alloc] init];
    shapeLayer.frame = CGRectMake(0, 10, 100, 100);
    shapeLayer.backgroundColor = [UIColor redColor].CGColor;
    [self.view.layer addSublayer:shapeLayer];
    
    
    UIBezierPath *path = [UIBezierPath bezierPathWithRect:CGRectMake(150, 10, 100, 100)];
    shapeLayer.path = path.CGPath;
    shapeLayer.fillColor = [UIColor clearColor].CGColor;
    shapeLayer.strokeColor = [UIColor blueColor].CGColor;
    [self.view.layer addSublayer:shapeLayer];
    
    
    CGSize drawImageSize = CGSizeMake(CGRectGetWidth(self.view.bounds), 300);
    float layerHeight = drawImageSize.height * 0.2;
    
    [path moveToPoint:CGPointMake(0, drawImageSize.height - layerHeight)];
    [path addLineToPoint:CGPointMake(0, drawImageSize.height - 1)];
    [path addLineToPoint:CGPointMake(drawImageSize.width, drawImageSize.height - 1)];
    [path addLineToPoint:CGPointMake(drawImageSize.width, drawImageSize.height - layerHeight)];
    [path addQuadCurveToPoint:CGPointMake(0, drawImageSize.height - layerHeight)
                 controlPoint:CGPointMake(drawImageSize.width/2, (drawImageSize.height - layerHeight) - layerHeight)];
    shapeLayer.path = path.CGPath;
    shapeLayer.fillColor = [UIColor brownColor].CGColor;
    shapeLayer.strokeColor = [UIColor purpleColor].CGColor;
    [self.view.layer addSublayer:shapeLayer];
    
    
    // transform
    CABasicAnimation *transformAnima = [CABasicAnimation animationWithKeyPath:@"transform.rotation.y"];
    transformAnima.fromValue = @(M_PI_2/4);
    transformAnima.toValue = @(M_PI/3);
    transformAnima.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    transformAnima.autoreverses = YES;
    transformAnima.repeatCount = HUGE_VALF;
    transformAnima.beginTime = CACurrentMediaTime() + 2;
    transformAnima.removedOnCompletion = NO;
    transformAnima.speed = 1.f;
    transformAnima.fillMode = kCAFillModeForwards;
    [shapeLayer addAnimation:transformAnima forKey:@"A"];
    
    /* shake
     animation.keyPath = @"position.x";
     animation.values = @[ @0, @10, @-10, @10, @0 ];
     animation.keyTimes = @[ @0, @(1 / 6.0), @(3 / 6.0), @(5 / 6.0), @1 ];
     animation.duration = 0.4;
     animation.additive = YES;
     [form.layer addAnimation:animation forKey:@"shake"];
     */
    
    [path addLineToPoint:CGPointZero];
    [path addLineToPoint:self.view.center];
    [path addLineToPoint:CGPointMake(CGRectGetWidth(self.view.bounds) * 0.7, CGRectGetHeight(self.view.bounds))];
    
    NSValue *value =  [NSValue valueWithCATransform3D:CATransform3DMakeRotation((-15) / 180.0 * M_PI, 0, 0, 1)];
    NSValue *value1 =  [NSValue valueWithCATransform3D:CATransform3DMakeRotation((15) / 180.0 * M_PI, 0, 0, 1)];
    NSValue *value2 =  [NSValue valueWithCATransform3D:CATransform3DMakeRotation((-15) / 180.0 * M_PI, 0, 0, 1)];
    
    
    CAKeyframeAnimation *keyframeAnimation = [CAKeyframeAnimation animation];
    [keyframeAnimation setPath:path.CGPath];
    keyframeAnimation.values = @[value,value1,value2];
    keyframeAnimation.duration = 3;
    keyframeAnimation.keyPath = @"transform";
    keyframeAnimation.repeatCount = MAXFLOAT;
    [shapeLayer addAnimation:keyframeAnimation forKey:@""];
}


@end
