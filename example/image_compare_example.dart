// Copyright (c) 2017, Matthew. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'package:angular/angular.dart';
import 'package:angular_image_compare/image_compare_component.dart';
import 'package:angular_image_compare/image_compare_component.template.dart' as ng;


void main() {
  runApp(ng.ImageCompareComponentNgFactory);
}

@Component(
    selector: 'custom-component',
    directives: const <dynamic>[ImageCompareComponent],
    template: '''
        <image-compare 
            [leftImage]="image1.jpg"
            [rightImage]="image2.jpg"
            [animate]="true">
        </image-compare>
        ''')
class CustomComponent {}
