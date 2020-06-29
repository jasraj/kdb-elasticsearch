// Elasticsearch API
// Copyright (c) 2019 Jaskirat Rajasansir

.require.lib each `type`time`convert;


/ The default MIME type of data that is sent via HTTP POST
.es.cfg.postMimeTypes:()!();
.es.cfg.postMimeTypes[`default]:    "application/json";
.es.cfg.postMimeTypes[`bulk]:       "application/x-ndjson";

/ The required separator JSON to allow upload of multiple objects in bulk
.es.cfg.bulkRowSeparator:"\n",.j.j[enlist[`index]!enlist ()!()],"\n";

.es.cfg.requiredUrlPrefix:":http*";

/ The target Elasticsearch instance
.es.target:`;


.es.init:{};


/ Configures the URL root of the Elasticsearch instance to use with this API
/  @param esInstance (Symbol) The root endpoint of the Elasticsearch instance (e.g. http://localhost:9200)
/  @throws InvalidElasticSearchUrlException If the instance endpoint specified is not http or https
/  @see .es.cfg.requiredUrlPrefix
/  @see .es.target
.es.setTargetInstance:{[esInstance]
    if[not .type.isSymbol esInstance;
        '"IllegalArgumentException";
    ];

    if[not esInstance like .es.cfg.requiredUrlPrefix;
        .log.if.error "Unsupported Elasticsearch API URL; must be HTTP or HTTPS [ URL: ",string[esInstance]," ]";
        '"InvalidElasticSearchInstanceException";
    ];

    if["/" = last string esInstance;
        esInstance:`$-1_ string esInstance;
    ];

    .es.target:esInstance;

    .log.if.info "Elasticsearch instance set [ URL: ",string[.es.target]," ]";
 };

/  @returns (Table) All the indices available in the current Elasticsearch instance
/  @see .es.http.get
.es.getAllIndices:{
    .log.if.info "Querying for all available indices from Elasticsearch";
    :.es.http.get "_cat/indices?v&format=json";
 };

/ Search a specific Elasticsearch instances for data via URL search
/  @param index (Symbol) The index to search within/ Use `$"_all" to search all indices
/  @param searchQuery (String) The search query as per the Elasticsearch documentation
/  @returns (Dict) The search results
/  @see .es.http.get
.es.search:{[index; searchQuery]
    if[not .type.isString searchQuery;
        '"IllegalArgumentException";
    ];

    :.es.http.get string[index],"/_search?q=",searchQuery;
 };

/  @param index (Symbol) The name of the index to retrieve the document from
/  @param id (Symbol) The ID of the document to retrieve
/  @returns The document as specified by the id from the specified index
/  @see .es.http.get
.es.getDocument:{[index; id]
    if[(not .type.isSymbol index) | not .type.isSymbol id;
        '"IllegalArgumentException";
    ];

    :.es.http.get index,`doc,id;
 };


/ HTTP GET interface function to Elasticsearch
/  @param relativeUrl (String|SymbolList) The URL to query on the Elasticsearch web API
/  @returns (Dict) The JSON response parsed into native kdb+ types
/  @see .es.i.buildUrl
/  @see .es.i.http10get
.es.http.get:{[relativeUrl]
    url:.es.i.buildUrl relativeUrl;

    .log.if.debug "Elasticsearch HTTP GET [ URL: ",string[url]," ]";

    :.j.k .es.i.http10get url;
 };

/ HTTP POST interface function to Elasticsearch for an indiviudal document
/ NOTE: To upload multiple documents, use .es.http.postBulk
/  @param index (Symbol) The target index to insert the new data. The index will be automatically appended with today's date if there is no date component specified in the index
/  @param id (Symbol) The ID of the entry to add. Set this to null symbol to allow Elasticsearch to generate its own
/  @parmam content (Dict|String) The content to be uploaded. If a dictionary is supplied, it will be converted to JSON. If a string is supplied, it's assumed to already be in JSON and will be uploaded directly
/  @returns (Dict) The JSON response parsed into native kdb+ types
/  @throws InvalidContentException If the content provided is not a string or dictionary type
/  @see .es.i.buildUrl
/  @see .es.i.normaliseIndex
/  @see .es.cfg.postMimeTypes
/  @see .Q.hp
.es.http.post:{[index; id; content]
    if[(not .type.isSymbol index) | not .type.isSymbol id;
        '"IllegalArgumentException";
    ];

    if[not any (.type.isDict; .type.isString)@\: content;
        '"InvalidContentException";
    ];

    if[not .type.isString content;
        content:.j.j content;
    ];

    if[.util.isEmpty id;
        id:`;
    ];

    url:.es.i.buildUrl .es.i.normaliseIndex[index],`doc,id;

    .log.if.debug "Elasticsearch HTTP POST [ URL: ",string[url]," ]";

    :.j.k .Q.hp[url; .es.cfg.postMimeTypes`default; content];
 };

/ Bulk HTTP POST interface function to Elasticsearch for multiple documents
/  @param index (Symbol) The target index to insert the new data. The index will be automatically appended with today's date if there is no date component specified in the index
/  @param contentTable (Table) The data to upload in bulk to Elasticsearch. Each row in the table will be a document
/  @returns (Dict) The JSON response parsed into native kdb+ types
/  @see .es.i.buildUrl
/  @see .es.i.normaliseIndex
/  @see .es.cfg.postMimeTypes
/  @see .es.i.http10post
.es.http.postBulk:{[index; contentTable]
    if[(not .type.isSymbol index) | not .type.isTable contentTable;
        '"IllegalArgumentException";
    ];

    if[0 < count keys contentTable;
        '"InvalidContentTableException";
    ];

    url:.es.i.buildUrl .es.i.normaliseIndex[index],`doc,`$"_bulk";

    content:.es.cfg.bulkRowSeparator,(.es.cfg.bulkRowSeparator sv .j.j each contentTable),"\n";

    .log.if.debug "Elasticsearch HTTP Bulk POST [ URL: ",string[url]," ] [ Size: ",string[count content]," bytes ]";

    :.j.k .es.i.http10post[url; .es.cfg.postMimeTypes`bulk; content];
 };


/ Ensure that the specified index has a date component (in yyyy.mm.dd format) within it
/  @param index (Symbol) The index to normalise
/  @returns (Symbol) The index unmodified if it has a date component, otherwise the original index with today's date appended to it
.es.i.normaliseIndex:{[index]
    if[not index like "*????.??.??*";
        .log.if.info "No date found in index name. Automatically adding today's date [ Index: ",string[index]," ]";
        index:`$"-" sv string (index; .time.today[]);
    ];

    :index;
 };

/ Elasticsearch URL builder
/  @param relativeUrl (String|Symbol|SymbolList) The relative URL requested by the calling function
/  @returns (Symbol) A complete URL that can be used with .Q.hg / .Q.hp
/  @see .es.target
/  @throws NoElasticsearchUrlException If the Elasticsearch API URL has not yet been set
/  @throws InvalidElasticSearchUrlException If the URL specified is of an incorrect type
.es.i.buildUrl:{[relativeUrl]
    if[null .es.target;
        .log.if.error "Cannot use Elasticsearch API, no instance specified yet [ Request URL: ",.Q.s1[relativeUrl]," ]";
        '"NoElasticsearchUrlException";
    ];

    if[.type.isString relativeUrl;
        if[not "/" = first relativeUrl;
            relativeUrl:"/",relativeUrl;
        ];

        :`$string[.es.target],relativeUrl;
    ];

    if[.type.isSymbol first relativeUrl;
        :` sv .es.target,relativeUrl;
    ];

    '"InvalidElasticSearchUrlException";
 };

/ HTTP GET downgraded to HTTP/1.0 (instead of HTTP/1.1) to disable "chunked" responses. The function interface matches .Q.hg
/  @see .es.i.http10hmb
.es.i.http10get:{[x]
    :.es.i.http10hmb[x; `GET; ()];
 };

/ HTTP POST downgraded to HTTP/1.0 (instead of HTTP/1.1) to disable "chunked" responses. The function interface matches .Q.hp
/  @see .es.i.http10hmb
.es.i.http10post:{[x;y;z]
    :.es.i.http10hmb[x; `POST; (y;z)];
 };

/ Modified version of .Q.hmb with the HTTP request downgraded to HTTP/1.0 to disable "chunked" responses due to the default .Q.hmb
/ not correctly reading the header response from Elasticsearch when operating in "chunked" mode
k).es.i.http10hmb:{x:$[10=@x;x;1_$x];p:{$[#y;y;x]}/getenv`$_:\("HTTP";"NO"),\:"_PROXY";u:.Q.hap@x;t:~(~#*p)||/(*":"\:u 2)like/:{(("."=*x)#"*"),x}'","\:p 1;a:$[t;p:.Q.hap@*p;u]1;(4+*r ss d)_r:(`$":",,/($[t;p;u]0 2))($y)," ",$[t;x;u 3]," HTTP/1.0",s,(s/:("Connection: close";"Host: ",u 2),((0<#a)#,$[t;"Proxy-";""],"Authorization: Basic ",.Q.btoa a),$[#z;("Content-type: ",z 0;"Content-length: ",$#z 1);()]),(d:s,s:"\r\n"),$[#z;z 1;""]};
