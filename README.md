# Elasticsearch API for kdb

This repository provides a kdb library to access Elasticsearch via its Web API. It provides the following features:

* Document retrieval and search
* Single and bulk document uploading

This library has been written for use with the [kdb-common](https://github.com/BuaBook/kdb-common) set of libraries.

## Usage

Once the library is loaded, the Elasticsearch Web API URL must be configured (with `.es.setTargetServer[esInstance]`) before using any other library functions. If you don't, you'll see a `NoElasticsearchUrlException`.

### `.es.setTargetServer[esInstance]`

Configures which Elasticsearch instance to interface with using this library. The URL should be symbol and be either HTTP or HTTPS.

Example:

```
q).es.setTargetInstance `:http://192.168.1.78:9200
2019.07.07 12:24:15.832 INFO pid-229 jas 0 Elasticsearch instance set [ URL: :http://192.168.1.78:9200 ]
```

### `.es.getAllIndices[]`

Provides information on all the indices available in the current Elasticsearch instance

Example:

```
q).es.getAllIndices[]
2019.07.07 12:26:25.279 INFO pid-322 jas 0 Querying for all available indices from Elasticsearch
health   status index                       uuid                     pri  rep  docs.count docs.deleted store.size pri.store.size
--------------------------------------------------------------------------------------------------------------------------------
"yellow" "open" "kdb-test-index-2019.07.07" "u0gG5DpCRVu56eBvPSMzOA" ,"1" ,"1" ,"2"       ,"0"         "3.9kb"    "3.9kb"
"yellow" "open" "kdb-test-index-2019.07.05" "2UBqNcBkQaSmGQR4PYJZEQ" ,"1" ,"1" ,"1"       ,"0"         "3.3kb"    "3.3kb"
```

### `.es.search[index; searchQuery]`

Allows a search to be performed on the specified index.

NOTE: This search is only a URI search so not all search options are available through this function. See the [URI search](https://www.elastic.co/guide/en/elasticsearch/reference/current/search-uri-request.html) section of the Elasticsearch documentation for more information

Example:

```
/ Insert some data to a new index
q) .es.http.post[`$"kdb-test-index2-2019.07.07"; `; `time`sym`price!(.z.p; `VOD.L; 1000f)];
q) .es.http.post[`$"kdb-test-index2-2019.07.07"; `; `time`sym`price!(.z.p; `VOD.L; 2000f)];

/ Search for entries where price = 2000
q) .es.search[`$"kdb-test-index2-2019.07.07"; "price:2000"]
took     | 0f
timed_out| 0b
_shards  | `total`successful`skipped`failed!1 1 0 0f
hits     | `total`max_score`hits!(`value`relation!(1f;"eq");1f;+`_index`_type`_id`_score`_source!(,"kdb-test-index2-2019.07.07";,"doc";,"UhBszGsBBs67mAIUf-jR";,1f;,`time`sym`price!("2019-07-07T12:3..
```

### `.es.getDocument[index; id]`

Retrieves a specific document from the a specific index

Example:

```
/ Once of the documents added in the .es.search example above
q) .es.getDocument[`$"kdb-test-index2-2019.07.07"; `URBszGsBBs67mAIUYeg1]
_index       | "kdb-test-index2-2019.07.07"
_type        | "doc"
_id          | "URBszGsBBs67mAIUYeg1"
_version     | 1f
_seq_no      | 0f
_primary_term| 1f
found        | 1b
_source      | `time`sym`price!("2019-07-07T12:33:05.180098000";"VOD.L";1000f)
```

### `.es.http.get[relativeUrl]`

Allows any Elasticsearch URL to be queried and the results returned. The library expects all returned data to be in JSON format to be oconverted into native kdb+ types

### `.es.http.post[index; id; content]`

Adds a new document to an index

* `index`: The name of the index to add the document to. The index will be automatically appended with today's date (in yyyy.mm.dd format) if there is no date component specified
* `id`: The ID of the entry to add. Generally this should be left as a null symbol to allow Elasticsearch to generate its own
* `content`: The content to be uploaded. It must be either a dictionary or a JSON string

Example:

```
q) .es.http.post[`$"kdb-test-index2"; `; `time`sym`price!(.z.p; `VOD.L; 2000f)]

2019.07.07 12:33:13.060 INFO pid-382 jas 0 No date found in index name. Automatically adding today's date [ Index: kdb-test-index2 ]

_index       | "kdb-test-index2-2019.07.07"
_type        | "doc"
_id          | "UhBszGsBBs67mAIUf-jR"
_version     | 1f
result       | "created"
_shards      | `total`successful`failed!2 1 0f
_seq_no      | 1f
_primary_term| 1f
```

### `.es.http.postBulk[index; contentTable]`

Allows multiple documents to be uploaded to an index in one operation via the [Bulk API](https://www.elastic.co/guide/en/elasticsearch/reference/current/docs-bulk.html).

* `index`: The name of the index to add the document to. The index will be automatically appended with today's date (in yyyy.mm.dd format) if there is no date component specified
* `contentTable`: The data to upload where each row of the table is a single document

If you want to specify custom IDs for each document to be added, ensure that the table provided has an `id` column

Example:

```
q) tbl:flip `col1`col2`col3!2?/:(`2; 100f; 1b)

q) .es.http.postBulk[`$"kdb-test-index4"; tbl]
2019.07.07 12:46:53.208 INFO pid-411 jas 0 No date found in index name. Automatically adding today's date [ Index: kdb-test-index4 ]
took  | 3f
errors| 0b
items | +(,`index)!,(`_index`_type`_id`_version`result`_shards`_seq_no`_primary_term`status!("kdb-test-index4-2019.07.07";"doc";"VhB5zGsBBs67mAIUA-h7";1f;"created";`total`successful`failed!2 1 0f;2..
```
