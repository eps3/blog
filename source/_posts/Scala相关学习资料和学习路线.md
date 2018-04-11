---
title: Scala相关学习资料和学习路线
date: 2017-08-19 02:41:35
categories:
  - 技术
tags:
  - Scala
  - 学习路线
description: scala相关深入学习的建议和阅读计划
---

#### 1. 书籍

- [快学Scala](https://book.douban.com/subject/19971952/)
- [Scala编程](https://book.douban.com/subject/5377415/)
- [Effective Scala](http://twitter.github.io/effectivescala/) / [Effective Scala 中文](http://twitter.github.io/effectivescala/index-cn.html)
- [Scala School](https://twitter.github.io/scala_school) / [Scala School 中文](https://twitter.github.io/scala_school/zh_cn/)
- [Akka入门与实践](https://book.douban.com/subject/27055163/)

#### 2. 视频

- [慕课网-Scala程序设计-基础篇-辰方](http://www.imooc.com/learn/613)  // 虽然只有基础部分，但讲的挺不错的
- [Scala基础课程](https://www.bilibili.com/video/av16124343/) // 我自己做的基础教程，轻拍.....


#### 3. 博客

- [Scala-Cool-水滴技术团队](https://scala.cool/) // 一些非常好的Scala技术文章翻译 
- [剥开Scala的糖衣-崔鹏飞](http://cuipengfei.me/blog/2013/05/05/how-are-scala-language-features-implemented/) // 对于Scala相关的语法糖进行非常详细的解释

----

#### 4. 如何学习

对于如何学习编程语言已经有各种如何学习Python/Java/JavaScript......，其实都大同小异，无外乎真正的去在项目中实践。对于学习Scala我的建议其实也不过如此。

##### 4.1 基本的Scala语法(不宜超过一周)
    - 值(可变，不可变)
    - 控制结构
    - 类和对象以及特质
    - 模式匹配
    - try-catch
    - 集合操作
    - ....

其实这部分如果有Java基础，也许需要的时间更少，你完全可以把Scala当作Java的另外一种语法，然后大量调用Java类库。

##### 4.2 逐渐深入
    - 隐式调用
    - 函数式编程、柯里化
    - 类型系统
    - ....

这部分需要找一些较为深入的资料和总结去学习，站在巨人的肩膀上效率会快很多。翻阅一些前人的博客会好很多。

##### 4.3 Akka与异步编程
    - Scala中的Future
    - 理解Actor模型
    - Akka分布式技术栈
    - ....

##### 4.4 Play Framework web开发
    - 异步与unblock io
    - ....

#### 5. 聊聊Java
对于已经从事Java开发的人来说，其实上手Scala是挺简单的，但是也容易写出过于"Java"的代码。虽然Scala也是OO语言，但Scala的编程风格和Java其实还是不一致的。如果你写了太多的Java代码，一时半会改过来可能还挺难受的。所以到底会Java对Scala有没有好处呢，当然是有的...... 但是太会了，也挺难受的。



----

一起分享Scala开发技术知识～ Q群:581882383