---
title: 理解Play线程池-翻译
date: 2017-09-26 02:41:49
categories:
  - 技术
tags:
  - Play
  - Scala
description: 如何对Play的线程优化，就看这篇就够啦！
---


> https://www.playframework.com/documentation/2.6.x/ThreadPools 译文
> 译者: @sheep3

Play Framework是一个自上而下、异步web框架。流(请求流？)使用Iteratee库进行异步处理。因为在play中IO操作永远不会阻塞的原因，Play中的线程池相对于传统web框架使用更少的线程数。

因此，如果你准备编写IO阻塞的代码或可能执行大量CPU密集型工作的代码，你需要明确的知道哪个线程池在进行工作，并作出相应的调整。如果不考虑这些进行阻塞IO可能会导致Play Framework的性能非常差，比如说，你可能会看到每秒只处理几个请求，且CPU的使用率只有5%。相比之下，一般开发环境下（例如，MacBook Pro）的基准(benchmarks)测试中显示，Play在正确调整线程池的情况下，无需费力就能处理每秒数百甚至上千请求的负载。



---

### 了解什么情况下你会阻塞

典型Play应用阻塞最常见的地方是与数据库通信时。可惜的是，没有什么常用数据库为JVM提供异步的数据库驱动，所以对于大多数数据库来说，你唯一的选择是使用阻塞IO。一个显著的例外是[ReactiveMongo](http://reactivemongo.org/)（一个MongoDB的驱动程序），它使用了Play的Iteratee库与MongoDB通信.

代码可能出现阻塞的其他情况包括：

- 使用第三方REST/WebService客户端的API（即不使用Play的异步WS API）
- 使用那些只提供同步API发送消息的消息传递技术
- 当你直接打开文件或者sockets时
- 因为需要长时间才能执行完成的CPU密集型操作而导致的阻塞

一般来说，如果你使用的API返回的是Futures，则是异步的，否则是阻塞的。

> 请注意，你可能会试图将你的代码封装在Futrues中。这不会使其成为非阻塞。这样只是以为着阻塞将会发生在另外一个线程中。你任然需要确保你使用的线程池具有足够多的线程来处理阻塞。可以查看http://playframework.com/download#examples上的Play事例代码，了解如何为阻塞API配置你Play应用。

相反，以下类型的IO不会阻塞：

- Play WS API
- 像ReactiveMongo这样的异步数据库驱动
- 发送/接受消息到Akka actors


---

### Play中的线程池

Play为不同的目的使用了多种不同的线程池

**> 内部线程池 -** 这些内部线程池处于内部服务器引擎用于处理IO。应用程序中的代码不应该由这些线程池中的线程执行。默认情况下，Play在后端配置了Akka HTTP服务器，因此需要使用application.conf中的[配置设置](https://www.playframework.com/documentation/2.6.x/SettingsAkkaHttp)来更改后端。或者，Play还带有一个Netty服务器后端，如果启用，也需要从application.conf[配置设置](https://www.playframework.com/documentation/2.6.x/SettingsNetty)。

**> Play默认线程池 -** 这是执行Play Framework中所有应用程序代码的线程池。它是一个Akka调度程序，由应用程序ActorSystem使用。可以通过配置Akka进行配置，如下所述。

---

### 使用默认线程池

Play Framework中的所有操作都使用默认线程池。在进行某些异步操作时，例如，执行future的map或者flatMap，你可能需要提供一个隐式的执行上下文(execution context)来执行给定的函数。执行上下文(execution context)基本上是线程池的另外一个名称。

在大多数情况下，合适的执行上下文将是**Play默认的线程池**。可以通过```@Inject()(implicit ec: ExecutionContext)```来访问，它将通过注入的方式到你的Scala源文件中使用。

```scala
class Samples @Inject()(components: ControllerComponents)(implicit ec: ExecutionContext) extends AbstractController(components) {
  def someAsyncAction = Action.async {
    someCalculation().map { result =>
      Ok(s"The answer is $result")
    }.recover {
      case e: TimeoutException =>
        InternalServerError("Calculation timed out!")
    }
  }

  def someCalculation(): Future[Int] = {
    Future.successful(42)
  }
}
```

或者在Java代码中使用带有HttpExecutionContext的CompletionStage：

```java
import play.libs.concurrent.HttpExecutionContext;
import play.mvc.*;

import javax.inject.Inject;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.CompletionStage;

public class MyController extends Controller {

    private HttpExecutionContext httpExecutionContext;

    @Inject
    public MyController(HttpExecutionContext ec) {
        this.httpExecutionContext = ec;
    }

    public CompletionStage<Result> index() {
        // Use a different task with explicit EC
        return calculateResponse().thenApplyAsync(answer -> {
            // uses Http.Context
            ctx().flash().put("info", "Response updated!");
            return ok("answer was " + answer);
        }, httpExecutionContext.current());
    }

    private static CompletionStage<String> calculateResponse() {
        return CompletableFuture.completedFuture("42");
    }
}

```

该执行上下文直接连接到应用程序的```ActorSystem```并使用[默认的调度器](http://doc.akka.io/docs/akka/2.5/scala/dispatchers.html)



#### 配置默认线程池

默认线程池可以使用application.conf中akka命名空间下的标准Akka配置进行配置。这是Play线程池的默认配置。

```yaml
akka {
  actor {
    default-dispatcher {
      fork-join-executor {
        # Settings this to 1 instead of 3 seems to improve performance.
        parallelism-factor = 1.0

        # @richdougherty: Not sure why this is set below the Akka
        # default.
        parallelism-max = 24

        # Setting this to LIFO changes the fork-join-executor
        # to use a stack discipline for task scheduling. This usually
        # improves throughput at the cost of possibly increasing
        # latency and risking task starvation (which should be rare).
        task-peeking-mode = LIFO
      }
    }
  }
}
```



这个配置指示Akka为每个可用处理器(per available processor)创建一个线程，池中最多包含24个线程。

你也可以尝试默认的Akka配置：

```yaml
akka {
  actor {
    default-dispatcher {
      # This will be used if you have set "executor = "fork-join-executor""
      fork-join-executor {
        # Min number of threads to cap factor-based parallelism number to
        parallelism-min = 8

        # The parallelism factor is used to determine thread pool size using the
        # following formula: ceil(available processors * factor). Resulting size
        # is then bounded by the parallelism-min and parallelism-max values.
        parallelism-factor = 3.0

        # Max number of threads to cap factor-based parallelism number to
        parallelism-max = 64

        # Setting to "FIFO" to use queue like peeking mode which "poll" or "LIFO" to use stack
        # like peeking mode which "pop".
        task-peeking-mode = "FIFO"
      }
    }
  }
}
```

可以在[这里](http://doc.akka.io/docs/akka/2.5.3/java/general/configuration.html#listing-of-the-reference-configuration)找到可用的完整配置选项



---

### 使用其他线程池



在某些情况下，您可能希望将任务调度到其他线程池。这可能包括CPU繁重的工作，或IO工作，如数据库访问。为此，你应该先创建一个ThreadPool，在Scala中这样可以轻松完成：

```scala
val myExecutionContext: ExecutionContext = akkaSystem.dispatchers.lookup("my-context")
```

在这种情况下，我们使用Akka来创建ExecutionContext，但是您也可以使用Java执行程序或Scala fork连接线程池轻松创建自己的ExecutionContexts。Play提供play.libs.concurrent.CustomExecutionContext和play.api.libs.concurrent.CustomExecutionContext用于创建自己的执行上下文。有关详细信息，请参阅[ScalaAsync](https://www.playframework.com/documentation/2.6.x/ScalaAsync)或[JavaAsync](https://www.playframework.com/documentation/2.6.x/JavaAsync)。

要配置此Akka执行上下文，可以将以下配置添加到application.conf中：

```yaml
my-context {
  fork-join-executor {
    parallelism-factor = 20.0
    parallelism-max = 200
  }
}
```

要在Scala中使用此执行上下文，您只需使用scala的Future伴生对象函数：

```scala
Future {
  // Some blocking or expensive code here
}(myExecutionContext)
```

或者你可以通过隐式调用他

```scala
implicit val ec = myExecutionContext

Future {
  // Some blocking or expensive code here
}
```

另外，请参阅http://playframework.com/download#examples上的事例，了解如何为阻塞API配置应用程序。



---

### 类加载器和thread locals

类加载器和thread locals需要在诸如Play程序的多线程环境中进行特殊处理

#### 应用程序类加载器

在一个Play应用程序中，[线程上下文类加载器](https://docs.oracle.com/javase/8/docs/api/java/lang/Thread.html#getContextClassLoader--)可能并不总是能够加载应用程序类。您应该明确地使用应用程序类加载器加载类。

Scala ->

```scala
val myClass = app.classloader.loadClass(myClassName)
```

Java ->

```java
Class myClass = app.classloader().loadClass(myClassName);
```

在开发模式（使用run）而不是生产模式运行Play时，明确的加载类是最重要的。是因为Play的开发模式使用多个类加载器，以便它可以支持自动应用程序重新加载。一些Play的线程可能绑定到一个只能知道应用程序类的一个子集的类加载器。

在某些情况下，您可能无法明确使用应用程序类加载器。使用第三方库时有时会出现这种情况。在这种情况下，您可能需要在调用第三方代码之前明确设置[线程上下文类加载器](https://docs.oracle.com/javase/8/docs/api/java/lang/Thread.html#getContextClassLoader--)。如果这样做，请记住在完成第三方代码的调用后，将上下文类加载器恢复到之前的值。

#### Java thread locals

Play中的Java代码使用ThreadLocal来查找诸如当前HTTP请求之类的上下文信息。Scala代码不需要使用ThreadLocals，因为它可以使用隐式参数来传递上下文。 ThreadLocals在Java中使用，因此Java代码可以访问上下文信息，而无需在任何地方传递上下文参数。

但是使用thread locals的问题是，一旦控制切换到另一个线程，就会丢失thread local信息。所以如果你使用thenApplyAsync map一个CompletionStage，或者在与该CompletionStage关联的Future未完成之后的某个时间点使用thenApply，然后尝试访问HTTP上下文（例如会话或请求），thread local不会正常工作。为了解决这个问题，Play提供了一个[HttpExecutionContext](https://www.playframework.com/documentation/2.6.x/api/java/play/libs/concurrent/HttpExecutionContext.html)。这可以让您捕获Executor中的当前上下文，然后可以将其传递给CompletionStage * Async方法，如thenApplyAsync()，当执行程序执行回调时，它将确保线程本地上下文被设置，以便您可以访问request/session/flash/response对象。

要使用HttpExecutionContext，将其注入到组件中，然后在CompletionStage与之交互时随时传递当前上下文。例如：

```java
import play.libs.concurrent.HttpExecutionContext;
import play.mvc.*;

import javax.inject.Inject;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.CompletionStage;

public class MyController extends Controller {

    private HttpExecutionContext httpExecutionContext;

    @Inject
    public MyController(HttpExecutionContext ec) {
        this.httpExecutionContext = ec;
    }

    public CompletionStage<Result> index() {
        // Use a different task with explicit EC
        return calculateResponse().thenApplyAsync(answer -> {
            // uses Http.Context
            ctx().flash().put("info", "Response updated!");
            return ok("answer was " + answer);
        }, httpExecutionContext.current());
    }

    private static CompletionStage<String> calculateResponse() {
        return CompletableFuture.completedFuture("42");
    }
}
```

如果你有一个自定义执行器，你可以把它包装到一个HttpExecutionContext中，只需把它传递给HttpExecutionContexts构造函数即可。



---

### 最佳实践

你应该如何最佳地在不同线程池之间划分应用程序中的工作很大程度上取决于你的应用程序正在执行的工作类型，以及要对多少工作可以并行执行的控制。没有一个大小适合所有解决问题的方法，最好的决定将来自于了解应用程序的阻塞IO要求及其对线程池的影响。它可能有助于对应用程序进行负载测试，以调整和验证您的配置。

> 注意：在阻塞环境中，thread-pool-executor比fork-join更好，因为没有work-stealing是可能的，而且应该使用fixed-pool-size并将其设置为底层资源的最大大小。
>
> 鉴于JDBC是阻塞的事实，假设线程池专用于数据库访问，线程池的大小可以设置为可用于数据库池的连接数。较少的线程不会消耗可用的连接数。连接数量多的线程相比之下可能会浪费，因为连接的争用。

下面我们将简要介绍一些人们可能希望在Play Framework中使用的常见配置文件：

#### 纯异步

在这种情况下，你在应用程序中不会出现阻塞IO。由于你永远不会阻塞，所以每个处理器的一个线程的默认配置完全符合您的用例，因此不需要额外的配置。在所有情况下都可以使用Play默认执行上下文。

#### 高度同步

此配置文件与传统的基于同步IO的Web框架（如Java servlet容器）匹配。它使用大的线程池来处理阻塞IO。它对于大多数操作正在进行数据库同步IO调用（例如访问数据库）的应用程序很有用，并且你不希望或需要控制不同类型工作的并发性。此配置文件是处理阻塞IO的最简单方法。

在此配置文件中，你将使用默认执行上下文，但配置它在其池中具有非常大量的线程。由于默认线程池用于服务播放请求和数据库请求，因此固定池大小应为数据库连接池的最大大小，加上内核数，加上一些额外的内务管理，如下所示：

```scala
akka {
  actor {
    default-dispatcher {
      executor = "thread-pool-executor"
      throughput = 1
      thread-pool-executor {
        fixed-pool-size = 55 # db conn pool (50) + number of cores (4) + housekeeping (1)
      }
    }
  }
}
```

对于执行同步IO的Java应用程序，建议使用此配置文件，因为在Java中将工作分配给其他线程更为困难。

另外，请参阅http://playframework.com/download#examples上的事例，了解如何为阻塞API配置应用程序。

#### 许多具体的线程池

此配置文件用于当你想要执行大量同步IO时，但你也想要准确地控制您的应用程序一次执行的操作的大小。在此配置文件中，你只会在默认执行上下文中执行非阻塞操作，然后将这些特定操作的阻塞操作分派到不同的执行上下文。

在这种情况下，你可能会为不同类型的操作创建一些不同的执行上下文，如下所示：

```scala
object Contexts {
  implicit val simpleDbLookups: ExecutionContext = akkaSystem.dispatchers.lookup("contexts.simple-db-lookups")
  implicit val expensiveDbLookups: ExecutionContext = akkaSystem.dispatchers.lookup("contexts.expensive-db-lookups")
  implicit val dbWriteOperations: ExecutionContext = akkaSystem.dispatchers.lookup("contexts.db-write-operations")
  implicit val expensiveCpuOperations: ExecutionContext = akkaSystem.dispatchers.lookup("contexts.expensive-cpu-operations")
}
```

他们可能进行如下配置：

```yaml
contexts {
  simple-db-lookups {
    executor = "thread-pool-executor"
    throughput = 1
    thread-pool-executor {
      fixed-pool-size = 20
    }
  }
  expensive-db-lookups {
    executor = "thread-pool-executor"
    throughput = 1
    thread-pool-executor {
      fixed-pool-size = 20
    }
  }
  db-write-operations {
    executor = "thread-pool-executor"
    throughput = 1
    thread-pool-executor {
      fixed-pool-size = 10
    }
  }
  expensive-cpu-operations {
    fork-join-executor {
      parallelism-max = 2
    }
  }
}
```

然后在你的代码中，你将创建Futures并传递相关的ExecutionContext以获取Future正在进行的工作类型。

> 注意：配置命名空间可以自由选择，只要它匹配传递给app.actorSystem.dispatchers.lookup的调度器ID即可。CustomExecutionContext类将为您自动执行此操作。

#### 几个具体的线程池

这是许多特定线程池和高度同步线程池的配置文件之间的组合。你将在默认执行上下文中执行最简单的IO，并将线程数设置为相当高（例如100），然后将某些昂贵的操作发送到特定上下文，在那里你可以限制一次完成的数量。



---

### 调试线程池

调度程序有很多可能的设置，可能很难看出哪些应用程序和默认设置是什么，特别是在覆盖默认调度程序时。akka.log-config-on-start配置选项显示应用程序加载时的整个应用配置：

```scala
akka.log-config-on-start = on
```

请注意，你必须将Akka日志记录设置为调试级别才能看到输出，因此你应该将以下内容添加到logback.xml中：

```scala
<logger name="akka" level="DEBUG" />
```

一旦看到记录的HOCON输出，您可以将其复制并粘贴到“example.conf”文件中，并在IntelliJ IDEA中进行查看，它支持HOCON语法。你应该看到你的更改与Akka的调度器合并，因此如果你重写`thread-pool-executor` ，你将看到他的合并。

```scala
{ 
  # Elided HOCON... 
  "actor" : {
    "default-dispatcher" : {
      # application.conf @ file:/Users/wsargent/work/catapi/target/universal/stage/conf/application.conf: 19
      "executor" : "thread-pool-executor"
    }
  }
}
```

还要注意，Play中的开发者模式和生产条件下具有不同的配置设置。要确保线程池设置正确，您应该在[生产配置](https://www.playframework.com/documentation/2.6.x/Deploying#Running-a-test-instance)中运行Play。



---

下一步：[配置Akka Http服务器后端](https://www.playframework.com/documentation/2.6.x/SettingsAkkaHttp)


