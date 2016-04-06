// This file was generated by nomdl/codegen.
// @flow
/* eslint-disable */

import {
  Field as _Field,
  Kind as _Kind,
  Package as _Package,
  Ref as _Ref,
  makeCompoundType as _makeCompoundType,
  makeStructType as _makeStructType,
  makeType as _makeType,
  registerPackage as _registerPackage,
} from '@attic/noms';
import type {
  NomsList as _NomsList,
  Struct as _Struct,
} from '@attic/noms';

{
  const pkg = new _Package([
    _makeStructType('Tree',
      [
        new _Field('children', _makeCompoundType(_Kind.List, _makeType(new _Ref(), 0)), false),
      ],
      [

      ]
    ),
  ], [
  ]);
  _registerPackage(pkg);
}


export interface Tree extends _Struct {
  children: _NomsList<Tree>;  // readonly
  setChildren(value: _NomsList<Tree>): Tree;
}
