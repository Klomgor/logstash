---
mapped_pages:
  - https://www.elastic.co/guide/en/logstash/current/persistent-queues.html
---

# Persistent queues (PQ) [persistent-queues]

A {{ls}} persistent queue helps protect against data loss during abnormal termination by storing the in-flight message queue to disk.

## Benefits of persistent queues [persistent-queues-benefits]

A persistent queue (PQ):

* Helps protect against message loss during a normal shutdown and when Logstash is terminated abnormally. If Logstash is restarted while events are in-flight, Logstash attempts to deliver messages stored in the persistent queue until delivery succeeds at least once.
* Can absorb bursts of events without needing an external buffering mechanism like Redis or Apache Kafka.

::::{note}
Persistent queues are disabled by default. To enable them, check out [Configuring persistent queues](#configuring-persistent-queues).
::::



## Limitations of persistent queues [persistent-queues-limitations]

Persistent queues do not solve these problems:

* Input plugins that do not use a request-response protocol cannot be protected from data loss. Tcp, udp, zeromq push+pull, and many other inputs do not have a mechanism to acknowledge receipt to the sender. (Plugins such as beats and http, which **do** have an acknowledgement capability, are well protected by this queue.)
* Data may be lost if an abnormal shutdown occurs before the checkpoint file has been committed.
* A persistent queue does not handle permanent machine failures such as disk corruption, disk failure, and machine loss. The data persisted to disk is not replicated.

::::{tip}
Use the local filesystem for data integrity and performance. Network File System (NFS) is not supported.
::::



## Configuring persistent queues [configuring-persistent-queues]

To configure persistent queues, specify options in the Logstash [settings file](/reference/logstash-settings-file.md). Settings are applied to every pipeline.

When you set values for capacity and sizing settings, remember that the value you set is applied *per pipeline* rather than a total to be shared among all pipelines.

::::{tip}
If you want to define values for a specific pipeline, use [`pipelines.yml`](/reference/multiple-pipelines.md).
::::


`queue.type`
:   Specify `persisted` to enable persistent queues. By default, persistent queues are disabled (default: `queue.type: memory`).

`path.queue`
:   The directory path where the data files will be stored. By default, the files are stored in `path.data/queue`.

`queue.page_capacity`
:   The queue data consists of append-only files called "pages." This value sets the maximum size of a queue page in bytes. The default size of 64mb is a good value for most users, and changing this value is unlikely to have performance benefits. If you change the page capacity of an existing queue, the new size applies only to the new page.

`queue.drain`
:   Specify `true` if you want Logstash to wait until the persistent queue is drained before shutting down. The amount of time it takes to drain the queue depends on the number of events that have accumulated in the queue. Therefore, you should avoid using this setting unless the queue, even when full, is relatively small and can be drained quickly.

`queue.max_events`
:   The maximum number of events not yet read by the pipeline worker. The default is 0 (unlimited). We use this setting for internal testing. Users generally shouldn’t be changing this value.

`queue.max_bytes`
:   The total capacity of *each queue* in number of bytes. Unless overridden in `pipelines.yml` or central management, each persistent queue will be sized at the value of `queue.max_bytes` specified in `logstash.yml`. The default is 1024mb (1gb).

    ::::{note}
    Be sure that your disk has sufficient capacity to handle the cumulative total of `queue.max_bytes` across all persistent queues. The total of `queue.max_bytes` for *all* queues should be lower than the capacity of your disk.
    ::::


    ::::{tip}
    If you are using persistent queues to protect against data loss, but don’t require much buffering, you can set `queue.max_bytes` to a smaller value as long as it is not less than the value of `queue.page_capacity`. A smaller value produces smaller queues and improves queue performance.
    ::::


`queue.checkpoint.acks`
:   Sets the number of acked events before forcing a checkpoint. Default is `1024`. Set to `0` for unlimited.

`queue.checkpoint.writes`
:   Sets the maximum number of written events before a forced checkpoint. Default is `1024`. Set to `0` for unlimited.

    To avoid losing data in the persistent queue, you can set `queue.checkpoint.writes: 1` to force a checkpoint after each event is written. Keep in mind that disk writes have a resource cost. Setting this value to `1` ensures maximum durability, but can severely impact performance. See [Controlling durability](#durability-persistent-queues) to better understand the trade-offs.



## Configuration notes [pq-config-notes]

Every situation and environment is different, and the "ideal" configuration varies. If you optimize for performance, you may increase your risk of losing data. If you optimize for data protection, you may impact performance.

### Queue size [pq-size]

You can control queue size with the `queue.max_events` and  `queue.max_bytes` settings. If both settings are specified, Logstash uses whichever criteria is reached first. See [Handling back pressure](#backpressure-persistent-queue) for behavior when queue limits are reached.

Appropriate sizing for the queue depends on the use-case. As a general guiding principle, consider this formula to size your persistent queue.

```txt
Bytes Received Per Second = Incoming Events Per Second * Raw Event Byte Size
Bytes Received Per Hour = Bytes Received per Second * 3600s
Required Queue Capacity = (Bytes Received Per Hour * Tolerated Hours of Downtime) * Multiplication Factor <1>
```

1. To start, you can set the `Multiplication Factor` to `1.10`, and then refine it for specific data types as indicated in the tables below.


#### Queue size by data type [sizing-by-type]

{{ls}} serializes the events it receives before they are stored in the queue. This process results in added overhead to the event inside {{ls}}. This overhead depends on the type and the size of the `Original Event Size`. As such, the `Multiplication Factor` changes depending on your use case. These tables show examples of overhead by event type and how that affects the multiplication factor.

**Raw string message**

| Plaintext size (bytes) | Serialized {{ls}} event size (bytes) | Overhead (bytes) | Overhead (%) | Multiplication Factor |
| --- | --- | --- | --- | --- |
| 11 | 213 | `202` | `1836%` | `19.4` |
| 1212 | 1416 | `204` | `17%` | `1.17` |
| 10240 | 10452 | `212` | `2%` | `1.02` |

**JSON document**

| JSON document size (bytes) | Serialized {{ls}} event size (bytes) | Overhead (bytes) | Overhead (%) | Multiplication Factor |
| --- | --- | --- | --- | --- |
| 947 | 1133 | `186` | `20%` | `1.20` |
| 2707 | 3206 | `499` | `18%` | `1.18` |
| 6751 | 7388 | `637` | `9%` | `1.09` |
| 58901 | 59693 | `792` | `1%` | `1.01` |

**Example**

Let’s consider a {{ls}} instance that receives 1000 EPS and each event is 1KB, or 3.5GB every hour. In order to tolerate a downstream component being unavailable for 12h without {{ls}} exerting back-pressure upstream, the persistent queue’s `max_bytes` would have to be set to 3.6*12*1.10 = 47.25GB, or about 50GB.



### Smaller queue size [pq-lower-max_bytes]

If you are using persistent queues to protect against data loss, but don’t require much buffering, you can set `queue.max_bytes` to a smaller value. A smaller value may produce smaller queues and improves queue performance.

**Sample configuration**

```yaml
queue.type: persisted
queue.max_bytes: 10mb
```


### Fewer checkpoints [pq-fewer-checkpoints]

Setting `queue.checkpoint.writes` and `queue.checkpoint.acks` to `0` may yield maximum performance, but may have potential impact on durability.

In a situation where Logstash is terminated or there is a hardware-level failure, any data that has not been checkpointed, is lost. See [Controlling durability](#durability-persistent-queues) to better understand the trade-offs.


### PQs and pipeline-to-pipeline communication [pq-pline-pline]

Persistent queues can play an important role in your [pipeline-to-pipeline](/reference/pipeline-to-pipeline.md) configuration.

#### Use case: PQs and output isolator pattern [uc-isolator]

Here is a real world use case described by a Logstash user.

"*In our deployment, we use one pipeline per output, and each pipeline has a large PQ. This configuration allows a single output to stall without blocking the input (and thus all other outputs), until the operator can restore flow to the stalled output and let the queue drain.*"

"*Our real-time outputs must be low-latency, and our bulk outputs must be consistent. We use PQs to protect against stalling the real-time outputs more so than to protect against data loss in the bulk outputs. (Although the protection is nice, too).*"




## Troubleshooting persistent queues [troubleshooting-pqs]

Symptoms of persistent queue problems include {{ls}} or one or more pipelines not starting successfully, accompanied by an error message similar to this one.

```
message=>"java.io.IOException: Page file size is too small to hold elements"
```

This error indicates that the head page (the oldest in a directory and the one with lowest page id) has a size < 18 bytes, the size of a page header.

To research and resolve the issue:

1. Identify the queue (or queues) that may be corrupt by checking log files, or running the `pqcheck` utility.
2. Stop Logstash, and wait for it to shut down.
3. Run `pqrepair <path>` for each of the corrupted queues.

### `pqcheck` utility [pqcheck]

```
the `pqcheck` utility to identify which persistent queue--or queues--have been corrupted.
```
From LOGSTASH_HOME, run:

```txt
bin/pqcheck <queue_directory>
```

where `<queue_directory>` is the fully qualified path to the persistent queue location.

The `pqcheck utility` reads through the checkpoint files in the given directory and outputs information about the current state of those files. The utility outputs this information for each checkpoint file:

* Checkpoint file name
* Whether or not the page file has been fully acknowledged. A fully acknowledged page file indicates that all events have been read and processed.
* Page file name that the checkpoint file is referencing
* Size of the page file. A page file with a size of 0 results in the output `NOT FOUND`. In this case, run `pqrepair` against the specified queue directory.
* Page number
* First unacknowledged page number (only relevant in the head checkpoint)
* First unacknowledged event sequence number in the page
* First event sequence number in the page
* Number of events in the page
* Whether or not the page has been fully acknowledged

**Sample with healthy page file**

This sample represents a healthy queue with three page files. In this sample, Logstash is currently writing to `page.2` as referenced by `checkpoint.head`. Logstash is reading from `page.0` as referenced by `checkpoint.0`.

```txt
ubuntu@bigger:/usr/share/logstash$ bin/pqcheck /var/lib/logstash/queue/main/
Using bundled JDK: /usr/share/logstash/jdk
OpenJDK 64-Bit Server VM warning: Option UseConcMarkSweepGC was deprecated in version 9.0 and will likely be removed in a future release.
Checking queue dir: /var/lib/logstash/queue/main
checkpoint.1, fully-acked: NO, page.1 size: 67108864
  pageNum=1, firstUnackedPageNum=0, firstUnackedSeqNum=239675, minSeqNum=239675,
  elementCount=218241, isFullyAcked=no
checkpoint.head, fully-acked: NO, page.2 size: 67108864
  pageNum=2, firstUnackedPageNum=0, firstUnackedSeqNum=457916, minSeqNum=457916, elementCount=11805, isFullyAcked=no
checkpoint.0, fully-acked: NO, page.0 size: 67108864  <1>
  pageNum=0, firstUnackedPageNum=0, firstUnackedSeqNum=176126, minSeqNum=1,
  elementCount=239674, isFullyAcked=no <2>
```

1. Represents `checkpoint.0`, which refers to the page file `page.0`, and has a size of `67108864`.
2. Continuing for `checkpoint.0`, these lines indicate that the page number is `0`, the first unacknowledged event is number `176126`, there are `239674` events in the page file, the first event in this page file is event number `1`, and the page file has not been fully acknowledged. That is, there are still events left in the page file that need to be ingested.


**Sample with corrupted page file**

If Logstash doesn’t start and/or `pqcheck` shows an anomaly, such as `NOT_FOUND` for a page, run `pqrepair` on the queue directory.

```txt
bin/pqcheck /var/lib/logstash/queue/main/
Using bundled JDK: /usr/share/logstash/jdk
OpenJDK 64-Bit Server VM warning: Option UseConcMarkSweepGC was deprecated in version 9.0 and will likely be removed in a future release.
Checking queue dir: /var/lib/logstash/queue/main
checkpoint.head, fully-acked: NO, page.2 size: NOT FOUND <1>
  pageNum=2, firstUnackedPageNum=2, firstUnackedSeqNum=534041, minSeqNum=457916,
  elementCount=76127, isFullyAcked=no
```

1. `NOT FOUND` is an indication of a corrupted page file. Run `pqrepair` against the specified queue directory.


::::{note}
If the queue shows `fully-acked: YES` and 0 bytes, you can safely delete the file.
::::



### `pqrepair` utility [pqrepair]

The `pqrepair` utility tries to remove corrupt queue segments to bring the queue back into working order. It starts searching from the directory where is launched and looks for `data/queue/main`.

::::{note}
The queue may lose some data in this operation.
::::


From LOGSTASH_HOME, run:

```txt
bin/pqrepair <queue_directory>
```

where `<queue_directory>` is the fully qualified path to the persistent queue location.

There is no output if the utility runs properly.

The `pqrepair` utility requires write access to the directory. Folder permissions may cause problems when Logstash is run as a service. In this situation, use `sudo`.

```txt
/usr/share/logstash$ sudo -u logstash bin/pqrepair /var/lib/logstash/queue/main/
```

After you run `pqrepair`, restart Logstash to verify that the repair operation was successful.


### Draining the queue [draining-pqs]

You may encounter situations where you want to drain the queue. Examples include:

* Pausing new ingestion. There may be situations where you want to stop new ingestion, but still keep a backlog of data.
* PQ repair. You can drain the queue to route to a different PQ while repairing an old one.
* Data or workflow migration. If you are moving off a disk/hardware and/or migrating to a new data flow, you may want to drain the existing queue.

To drain the persistent queue:

1. In the `logstash.yml` file, set `queue.drain: true`.
2. Restart Logstash for this setting to take effect.
3. Shutdown Logstash (using CTRL+C or SIGTERM), and wait for the queue to empty.



## How persistent queues work [persistent-queues-architecture]

The queue sits between the input and filter stages in the same process:

input → queue → filter + output

When an input has events ready to process, it writes them to the queue. When the write to the queue is successful, the input can send an acknowledgement to its data source.

When processing events from the queue, Logstash acknowledges events as completed, within the queue, only after filters and outputs have completed. The queue keeps a record of events that have been processed by the pipeline. An event is recorded as processed (in this document, called "acknowledged" or "ACKed") if, and only if, the event has been processed completely by the Logstash pipeline.

What does acknowledged mean? This means the event has been handled by all configured filters and outputs. For example, if you have only one output, Elasticsearch, an event is ACKed when the Elasticsearch output has successfully sent this event to Elasticsearch.

During a normal shutdown (**CTRL+C** or SIGTERM), Logstash stops reading from the queue and finishes processing the in-flight events being processed by the filters and outputs. Upon restart, Logstash resumes processing the events in the persistent queue as well as accepting new events from inputs.

If Logstash is abnormally terminated, any in-flight events will not have been ACKed and will be reprocessed by filters and outputs when Logstash is restarted. Logstash processes events in batches, so it is possible that for any given batch, some of that batch may have been successfully completed, but not recorded as ACKed, when an abnormal termination occurs.

::::{note}
If you override the default behavior by setting `drain.queue: true`, Logstash reads from the queue until it is emptied—​even after a controlled shutdown.
::::


For more details specific behaviors of queue writes and acknowledgement, see [Controlling durability](#durability-persistent-queues).

### Handling back pressure [backpressure-persistent-queue]

When the queue is full, Logstash puts back pressure on the inputs to stall data flowing into Logstash. This mechanism helps Logstash control the rate of data flow at the input stage without overwhelming outputs like Elasticsearch.

Use `queue.max_bytes` setting to configure the total capacity of the queue on disk. The following example sets the total capacity of the queue to 8gb:

```yaml
queue.type: persisted
queue.max_bytes: 8gb
```

With these settings specified, Logstash buffers events on disk until the size of the queue reaches 8gb. When the queue is full of unACKed events, and the size limit has been reached, Logstash no longer accepts new events.

Each input handles back pressure independently. For example, when the [beats](logstash-docs-md://lsr/plugins-inputs-beats.md) input encounters back pressure, it no longer accepts new connections and waits until the persistent queue has space to accept more events. After the filter and output stages finish processing existing events in the queue and ACKs them, Logstash automatically starts accepting new events.


### Controlling durability [durability-persistent-queues]

Durability is a property of storage writes that ensures data will be available after it’s written.

When the persistent queue feature is enabled, Logstash stores events on disk. Logstash commits to disk in a mechanism called *checkpointing*.

The queue itself is a set of pages. There are two kinds of pages: head pages and tail pages. The head page is where new events are written. There is only one head page. When the head page is of a certain size (see `queue.page_capacity`), it becomes a tail page, and a new head page is created. Tail pages are immutable, and the head page is append-only. Second, the queue records details about itself (pages, acknowledgements, etc) in a separate file called a checkpoint file.

When recording a checkpoint, Logstash:

* Calls `fsync` on the head page.
* Atomically writes to disk the current state of the queue.

The process of checkpointing is atomic, which means any update to the file is saved if successful.

::::{important}
If Logstash is terminated, or if there is a hardware-level failure, any data that is buffered in the persistent queue, but not yet checkpointed, is lost.
::::


You can force Logstash to checkpoint more frequently by setting `queue.checkpoint.writes`. This setting specifies the maximum number of events that may be written to disk before forcing a checkpoint. The default is 1024. To ensure maximum durability and avoid data loss in the persistent queue, you can set `queue.checkpoint.writes: 1` to force a checkpoint after each event is written. Keep in mind that disk writes have a resource cost. Setting this value to `1` can severely impact performance.


### Disk garbage collection [garbage-collection]

On disk, the queue is stored as a set of pages where each page is one file. Each page can be at most `queue.page_capacity` in size. Pages are deleted (garbage collected) after all events in that page have been ACKed. If an older page has at least one event that is not yet ACKed, that entire page will remain on disk until all events in that page are successfully processed. Each page containing unprocessed events will count against the `queue.max_bytes` byte size.



