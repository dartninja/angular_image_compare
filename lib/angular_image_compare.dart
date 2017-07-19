// Copyright (c) 2017, Matthew. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.


import 'dart:async';
import 'dart:html' as html;
import 'dart:math';

import 'package:angular2/angular2.dart';
import 'package:angular2/router.dart';
import 'package:angular_components/angular_components.dart';


@Component(
    selector: 'image-compare',
    providers: const <dynamic>[materialProviders],
    directives: const <dynamic>[materialDirectives,
    ROUTER_DIRECTIVES,
    ],
    styles: const <dynamic>['''
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
    '''],
    template: '''
    <div style="width: 100%; height:100%;" #ruler></div>
    <div [style.width]="comparisonSplitPosition"
         style="position:absolute;left:0;top:0;overflow: hidden;height:100%">
        <div class="itemContainer" style="left:0;" [style.width]="comparisonWidth">
            <img #leftImage src="" />
        </div>
    </div>
    <div [style.left]="comparisonSplitPosition"
         style="position:absolute;right:0;top:0;overflow: hidden;height:100%">
        <div class="itemContainer" style="right:0;" [style.width]="comparisonWidth">
            <img #rightImage src="" />
        </div>
    </div>
    <div class="splitter" [style.left]="comparisonSplitPosition"></div>
    <div class="splitterHandle" 
         [style.left]="comparisonSplitPosition" draggable="true" (drag)="comparisonDrag(\$event)"
         (dragend)="cancelEvent(\$event)">
        <glyph icon="compare_arrows"></glyph>
    </div>
    ''')
class ImageCompareComponent implements OnInit, OnDestroy {
  bool _leftLoading = false, _rightLoading = false;

  bool get _loading => _leftLoading || _rightLoading;

  int leftWidth=0, leftHeight=0, rightWidth=0, rightHeight=0;


  @ViewChild("leftImage")
  ElementRef leftImageElement;

  @ViewChild("rightImage")
  ElementRef rightImageElement;


  @ViewChild("ruler")
  ElementRef ruler;


  @Input()
  set leftImage(String value) {
    _leftLoading = true;
    leftImageElement.nativeElement.src = value;
  }

  String get leftImage => leftImageElement.nativeElement.src;


  @Input()
  set rightImage(String value) {
    _rightLoading = true;
    rightImageElement.nativeElement.src = value;
  }

  String get rightImage => rightImageElement.nativeElement.src;


  @Input()
  double animationSpeed = 0.01;

  @Input()
  bool animate = true;

  double _comparisonSplitRatio = 0.5;

  /// true = right, false = left
  bool _animationDirection = true;

  Timer _comparisonTimer;

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
    if (leftWidth== null) return 0;
    final Point p = fitWithin(
        new Point(leftWidth, leftHeight),
        new Point(comparisonWidthInt, comparisonHeightInt));
    final double halfWidth = (comparisonWidthInt / 2);
    final double halfImage = (p.x / 2);
    final int output = (halfWidth - halfImage).round();
    if (output < 0) return 0;
    return output;
  }

  int get rightComparisonLimit {
    if (rightWidth == null) return 0;
    final Point p = fitWithin(
        new Point(rightWidth, rightHeight),
        new Point(comparisonWidthInt, comparisonHeightInt));
    final double halfWidth = (comparisonWidthInt / 2);
    final double halfImage = (p.x / 2);
    final int output = (halfWidth + halfImage).round();
    if (output > comparisonWidthInt) return comparisonWidthInt;
    return output;
  }

  String get secondComparisonWidth => "${rightWidth??0}px";

  Future<Null> animationCallback(Timer t) async {
    if (animate) {
      if (_animationDirection) {
        //right
        if (comparisonSplitPositionInt > leftComparisonLimit) {
          await wait();
          _comparisonSplitRatio -= animationSpeed;
        } else {
          _animationDirection = false;
        }
      } else {
        //left
        if (comparisonSplitPositionInt < rightComparisonLimit) {
          await wait();
          _comparisonSplitRatio += animationSpeed;
        } else {
          _animationDirection = true;
        }
      }
    }
  }

  void comparisonDrag(html.MouseEvent event) {
    animate = false;
    event.preventDefault();
    event.stopPropagation();
    if(event.client.x==0)
      return;
    //final int offset =event.movement.x;
    final html.DivElement rulerDiv =  ruler.nativeElement;

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

  StreamSubscription<html.Event> _leftLoaded;
  StreamSubscription<html.Event> _rightLoaded;

  @override
  void ngOnInit() {

    _leftLoaded = leftImageElement.nativeElement.onLoad.listen((html.Event e) {
      _leftLoading = false;
      leftWidth = leftImageElement.nativeElement.naturalWidth;
      leftHeight = leftImageElement.nativeElement.naturalHeight;
    });
    _rightLoaded = rightImageElement.nativeElement.onLoad.listen((html.Event e) {
      _rightLoading = false;
      rightWidth = rightImageElement.nativeElement.naturalWidth;
      rightHeight = rightImageElement.nativeElement.naturalHeight;
    });

    new Timer(new Duration(seconds: 1), () {
      _comparisonTimer =
      new Timer.periodic(new Duration(milliseconds: 16), animationCallback);
    });
  }
}
