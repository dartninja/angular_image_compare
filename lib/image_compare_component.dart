// Copyright (c) 2017, Matthew. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:html' as html;
import 'dart:math';

import 'package:angular2/angular2.dart';
import 'package:angular2/platform/common.dart';
import 'package:angular2/router.dart';
import 'package:angular_components/angular_components.dart';

@Component(
    selector: 'image-compare',
    providers: const <dynamic>[materialProviders],
    directives: const <dynamic>[
      COMMON_DIRECTIVES,
      materialDirectives,
      ROUTER_DIRECTIVES,
      NgClass,
    ],
    styles: const <dynamic>[
      '''
.splitter {
    position: absolute;
    top: 0;
    width: 1px;
    background-color: black;
    height: 100%;
}
.itemContainer img {
    object-fit: contain;
    width:100%;
    height:100%;
}

.itemContainer {
    text-align: center;
    position: absolute;
    top: 0;
    width:100vw;
    height: 100%;
}
.splitterHandle {
position:absolute;top:50%;height:24px;width: 24px;background-color: black;border-radius: 50%;color:white;margin-left:-12px;margin-top:-12px;cursor:ew-resize;
}
:host {
    display:block;
    border: solid 1px black;
    position:relative;
    overflow:hidden;
}
.switcherView {
  width:100%;
  height:100%;
}
.switcherView img {
  width:100%;
  height: calc(100% - 30pt);
  object-fit: contain;
}
    '''
    ],
    template: '''
    <div *ngIf="!splitView" class="switcherView">
      <img id="firstSwitcherImage" src="{{leftImage}}" *ngIf="leftImageVisible">      
      <img id="secondSwitcherImage" src="{{rightImage}}" *ngIf="rightImageVisible">    
      <material-progress [activeProgress]="countdownProgress"></material-progress>
      <material-button icon><glyph icon="left_arrow"></glyph></material-button>  
      <material-button icon><glyph icon="left_arrow"></glyph></material-button>  
    </div>
    <div style="width: 100%; height:100%;" #ruler></div>
    <div *ngIf="splitView" [style.width]="comparisonSplitPosition"
         style="position:absolute;left:0;top:0;overflow: hidden;height:100%">
        <div class="itemContainer" style="left:0;" [style.width]="comparisonWidth">
            <img #leftImage src="{{leftImage}}" (load)="onLeftImageLoad(\$event)" />
        </div>
    </div>
    <div *ngIf="splitView" [style.left]="comparisonSplitPosition"
         style="position:absolute;right:0;top:0;overflow: hidden;height:100%">
        <div class="itemContainer" style="right:0;" [style.width]="comparisonWidth">
            <img #rightImage src="{{rightImage}}" (load)="onRightImageLoad(\$event)" />
        </div>
    </div>
    <div *ngIf="splitView" class="splitter" [style.left]="comparisonSplitPosition"></div>
    <div *ngIf="splitView" class="splitterHandle" 
         [style.left]="comparisonSplitPosition" draggable="true" (drag)="comparisonDrag(\$event)"
         (dragend)="cancelEvent(\$event)">
        <glyph icon="compare_arrows"></glyph>
    </div>
    ''')
class ImageCompareComponent implements OnInit, OnDestroy {
  bool _leftLoading = false, _rightLoading = false;

  int leftWidth = 0, leftHeight = 0, rightWidth = 0, rightHeight = 0;

  bool leftImageVisible = true;
  bool rightImageVisible = false;

  @ViewChild("leftImage")
  ElementRef leftImageElement;

  @ViewChild("rightImage")
  ElementRef rightImageElement;

  @ViewChild("ruler")
  ElementRef ruler;

  bool _animate = true;

  @Input()
  bool splitView = false;

  @Input()
  double duration = 5.0;

  double _comparisonSplitRatio = 0.5;

  /// true = right, false = left
  bool _animationDirection = true;

  Timer _comparisonTimer;

  StreamSubscription<html.Event> _leftLoaded;

  StreamSubscription<html.Event> _rightLoaded;

  String _leftImageSource;

  String _rightImageSource;

  DateTime _lastFrameTime = new DateTime.now();

  bool get animate => _animate;

  @Input()
  set animate(bool value) {
    if (!_animate && value) _lastFrameTime = new DateTime.now();
    _animate = value;
  }

  String get comparisonHeight {
    return "${comparisonHeightInt}px";
  }

  int get comparisonHeightInt => ruler.nativeElement.offsetHeight;

  String get comparisonSplitPosition {
    return "${comparisonSplitPositionInt}px";
  }

  int get comparisonSplitPositionInt {
    int x = (comparisonWidthInt * _comparisonSplitRatio).round();
    if (x < leftComparisonLimit) x = leftComparisonLimit;
    if (x > rightComparisonLimit) x = rightComparisonLimit;

    if (x < 0) x = 0;
    return x;
  }

  String get comparisonWidth {
    return "${comparisonWidthInt}px";
  }

  int get comparisonWidthInt => ruler.nativeElement.offsetWidth;

  String get firstComparisonWidth => "${leftWidth??0}px";
  int get leftComparisonLimit {
    if (leftWidth == null) return 0;
    final Point p = _fitWithin(new Point(leftWidth, leftHeight),
        new Point(comparisonWidthInt, comparisonHeightInt));
    final double halfWidth = (comparisonWidthInt / 2);
    final double halfImage = (p.x / 2);
    final int output = (halfWidth - halfImage).round();
    if (output < 0) return 0;
    return output;
  }

  String get leftImage => _leftImageSource;

  @Input()
  set leftImage(String value) {
    _leftLoading = true;
    _leftImageSource = value;
    if(leftImageElement!=null)
      leftImageElement.nativeElement.src = value;
  }

  int get rightComparisonLimit {
    if (rightWidth == null) return 0;
    final Point p = _fitWithin(new Point(rightWidth, rightHeight),
        new Point(comparisonWidthInt, comparisonHeightInt));
    final double halfWidth = (comparisonWidthInt / 2);
    final double halfImage = (p.x / 2);
    final int output = (halfWidth + halfImage).round();
    if (output > comparisonWidthInt) return comparisonWidthInt;
    return output;
  }
  String get rightImage => _rightImageSource;

  @Input()
  set rightImage(String value) {
    _rightLoading = true;
    _rightImageSource = value;
    if(rightImageElement!=null)
      rightImageElement.nativeElement.src = value;
  }

  String get secondComparisonWidth => "${rightWidth??0}px";

  bool get _loading => _leftLoading || _rightLoading;

  void cancelEvent(html.Event e) {
    e.stopPropagation();
    e.preventDefault();
    e.stopImmediatePropagation();
  }

  void comparisonDrag(html.MouseEvent event) {
    animate = false;
    event.preventDefault();
    event.stopPropagation();
    if (event.client.x == 0) return;
    //final int offset =event.movement.x;
    final html.DivElement rulerDiv = ruler.nativeElement;

    final int offset = event.client.x - rulerDiv.offset.left;

    final double adjustRatio = offset / comparisonWidthInt;
    _comparisonSplitRatio = adjustRatio;
  }

  @override
  void ngOnDestroy() {
    _comparisonTimer?.cancel();
    _leftLoaded?.cancel();
    _rightLoaded?.cancel();
  }

  @override
  void ngOnInit() {
    new Timer(new Duration(seconds: 1), () {
      _comparisonTimer = new Timer.periodic(
          new Duration(milliseconds: 16), _animationCallback);
    });
  }

  void onLeftImageLoad(html.Event e) {
    _leftLoading = false;
    leftWidth = e.target.naturalWidth;
    leftHeight = e.target.naturalHeight;
  }

  void onRightImageLoad(html.Event e) {
    _rightLoading = false;
    rightWidth = e.target.naturalWidth;
    rightHeight = e.target.naturalHeight;
  }

  int countdownProgress = 0;

  Future<Null> _animationCallback(Timer t) async {
    if (animate) {
      Duration frameTime = new DateTime.now().difference(_lastFrameTime);
      double delta = (frameTime.inMilliseconds / 1000) / duration;
      if (splitView) {

        if (_animationDirection) {
          //right
          if (comparisonSplitPositionInt > leftComparisonLimit) {
            await _wait();
            _comparisonSplitRatio -= delta;
          } else {
            _animationDirection = false;
          }
        } else {
          //left
          if (comparisonSplitPositionInt < rightComparisonLimit) {
            await _wait();
            _comparisonSplitRatio += delta;
          } else {
            _animationDirection = true;
          }
          _lastFrameTime = new DateTime.now();
        }
      } else {
        // Not split view, just simple image change
        if(rightImageVisible) {
          countdownProgress = 100-(delta*100).round();
        } else {
          countdownProgress = (delta*100).round();
        }
        if ((frameTime.inMilliseconds / 1000) >= duration) {
          leftImageVisible = !leftImageVisible;
          rightImageVisible = !rightImageVisible;
          _lastFrameTime = new DateTime.now();
        }
      }
    }
  }

  Point _fitWithin(Point inner, Point outer) {
    final double outerRatio = outer.x / outer.y;
    final double innerRatio = inner.x / inner.y;

    if (outerRatio < innerRatio) {
      final num x = outer.x;
      final num y = inner.y * (outer.x / inner.x);
      return new Point(x, y);
    } else if (outerRatio > innerRatio) {
      final num y = outer.y;
      final num x = inner.x * (outer.y / inner.y);
      return new Point(x, y);
    } else {
      return new Point(outer.x, outer.y);
    }
  }

  Future<Null> _wait({int milliseconds: 100}) {
    final Completer<Null> completer = new Completer<Null>();
    new Timer(new Duration(milliseconds: milliseconds), () {
      completer.complete();
    });
    return completer.future;
  }
}
