Bit.ly Api Key
--------------
UID: tiviguide
Key: R_8ee80122d7bb3b807f246941c084ddf0

How to Get Blog posts for a TV Show
-----------------------------------
1. Establish a connection to the TiVi

    connection = XMLRPC::Client.new2('http://tivi.co.ke/xmlrpc.php')

2. Get the categories for a particular blog

    http://codex.wordpress.org/XML-RPC_WordPress_API

    categories = connection.call('wp.getTerms',1,<username>,<password>, 'category')

    These categories should be cached for a duration because they are not likely to be changed that often

    {"term_id"=>"4",
      "name"=>"Actors/ Actresses",
      "slug"=>"actors-actresses",
      "term_group"=>"0",
      "term_taxonomy_id"=>"4",
      "taxonomy"=>"category",
      "description"=> "Know about your favorite actors and actresses and what tey have been up to",
      "parent"=>"0",
      "count"=>6}

3. Perform a json query to a url with the category id returning json
    The category id is from the term_id above
    Compare the name of the show to the name of the category

    See http://wordpress.org/extend/plugins/json-api/other_notes/

    res = HTTParty.get('http://tivi.co.ke/?cat=<category_id>&json=1')
