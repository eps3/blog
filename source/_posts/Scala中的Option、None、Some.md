---
title: Scala中的Option、None、Some
date: 2017-11-15 02:41:20
categories:
  - 技术
tags:
  - Scala
description: 从源码的角度去理解Scala中的Option、None、Some
---

> 先大概看看源码

#### Option

```scala
sealed abstract class Option[+A] extends Product with Serializable {
  self =>

  // 是否为空
  def isEmpty: Boolean

  // 数据值
  def get: A
  
  def isDefined: Boolean = !isEmpty
  
  //...
}
```

#### None

```scala
case object None extends Option[Nothing] {
  def isEmpty = true
  def get = throw new NoSuchElementException("None.get")
}
```

#### Some

```scala
final case class Some[+A](value: A) extends Option[A] {
  def isEmpty = false
  def get = value
}
```

#### Tip

直接看源码很明显，`Some`和`None`都是Option的具体实现，而且这部分实现很简单

当我们定义一个空的Option时直接

```scala
val x:Option[String] = None
```

如果是有具体的值，则

```scala
val x:Option[String] = Some("xxx")
```



*在来看看Option的伴生对象*

```scala
object Option {
  // Option(null) 其实返回的就是None
  def apply[A](x: A): Option[A] = if (x == null) None else Some(x)
  // Option.empty[A]其实就是返回一个类型为Option[A]的None
  def empty[A] : Option[A] = None
}
```

Scala项目里有时不得不参杂一些“Java”的代码，我们可能要做很多null的判断，这时我们可以直接使用`Option`的一些方法直接将非Option对象转换为Option对象。

```scala
// x 可能为null

val y = Option(x)
```

