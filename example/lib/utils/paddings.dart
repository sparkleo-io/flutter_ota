import 'package:flutter/material.dart';

double paddingFull = 20;
double paddingHalf = 10;

EdgeInsets edgeInsetsAllFull = EdgeInsets.all(paddingFull);
EdgeInsets edgeInsetsAllHalf = EdgeInsets.all(paddingHalf);
EdgeInsets edgeInsetsHorizontalHalf =
    EdgeInsets.symmetric(horizontal: paddingHalf);
EdgeInsets edgeInsetsHorizontalFull =
    EdgeInsets.symmetric(horizontal: paddingFull);

Container containerAllFull = Container(
  padding: edgeInsetsAllFull,
);
Container containerAllHalf = Container(
  padding: edgeInsetsAllHalf,
);

Container containerLeftFull = Container(
  padding: EdgeInsets.only(left: paddingFull),
);
Container containerTopFull = Container(
  padding: EdgeInsets.only(top: paddingFull),
);

Container containerTopHalf = Container(
  padding: EdgeInsets.only(top: paddingHalf),
);
Container containerLeftHalf = Container(
  padding: EdgeInsets.only(left: paddingHalf),
);

/**
 * These are the standard paddings to be used in the app. Whenever you have to add
 * space or padding just use the respective variable from here
 */