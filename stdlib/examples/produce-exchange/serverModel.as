/**

[PESS Background](https://github.com/dfinity-lab/actorscript/tree/stdlib-examples/design/stdlib/examples/produce-exchange#Produce-Exchange-Standards-Specification-PESS)
--------------------

Server Model
===============================

**[`Server` actor class](https://github.com/dfinity-lab/actorscript/blob/stdlib-examples/design/stdlib/examples/produce-exchange/serverActor.md)**
defines an interface for messages sent by all participants, and the responses received in return.


Here, we depart from defining PESS data types and messages, and
instead turn our attention to the _internal representation_ of the
server actor's state, defined by the **[server model
types](https://github.com/dfinity-lab/actorscript/blob/stdlib-examples/design/stdlib/examples/produce-exchange/serverModelTypes.md)**,
and the _outer behavior_ of this `Server` actor.  The latter behavior
is part of the PESS definition, and the internal type definitions that it
uses are is not.

*/

class Model() = this {

  /**
   Misc helpers
   ==================
   */

  private unwrap<T>(ox:?T) : T {
    switch ox {
    case (null) { assert false ; unwrap<T>(ox) };
    case (?x) x;
    }
  };

  private idIsEq(x:Nat,y:Nat):Bool { x == y };

  private idHash(x:Nat):Hash { null /* xxx */ };

  private keyOf(x:Nat):Key<Nat> {
    new { key = x ; hash = idHash(x) }
  };


/**

Representation
=================

We use several public-facing **tables**, implemented as document tables.


CRUD operations via [document tables](https://github.com/dfinity-lab/actorscript/blob/stdlib-examples/design/stdlib/docTable.md)
----------------------------------------------------

This server model provides [document table](https://github.com/dfinity-lab/actorscript/blob/stdlib-examples/design/stdlib/docTable.md) objects to hold the
following kinds of entities in the exchange:

- **Static resource information:** truck types, produce types and region information.
- **Participant information:** producers, retailers and transporters.
- **Dynamic resource information:** inventory, routes and reservations.

For each of the entity kinds listed above, we have a corresponding
`DocTable` defined below that affords ordinary CRUD
(create-read-update-delete) operations.


Secondary maps
----------------------

See also [indexing by `RegionId`](#indexing-by-regionid).

The secondary maps and intra-document maps enable faster query
performance.

When we update the primary tables, we update any associated
secondary indices maps and intra-document maps as well, to keep them
all in sync.

**To do:** We initialize the primary tables with callbacks that
refer to the secondary maps; the callbacks intercept add/remove
operations to maintain consistency between the primary tables and the
secondary maps.

*/

  /**
   `truckTypeTable`
   -----------------
   */

  var truckTypeTable : TruckTypeTable =
    DocTable<TruckTypeId, TruckTypeDoc, TruckTypeInfo>(
    0,
    func(x:TruckTypeId):TruckTypeId{x+1},
    func(x:TruckTypeId,y:TruckTypeId):Bool{x==y},
    idHash,
    func(doc:TruckTypeDoc):TruckTypeInfo = shared {
      id=doc.id;
      short_name=doc.short_name;
      description=doc.description;
      capacity=doc.capacity;
      isFridge=doc.isFridge;
      isFreezer=doc.isFreezer;
    },
    func(info:TruckTypeInfo):?TruckTypeDoc = ?(new {
      id=info.id;
      short_name=info.short_name;
      description=info.description;
      capacity=info.capacity;
      isFridge=info.isFridge;
      isFreezer=info.isFreezer;
    }),
  );

  /**
   `regionTable`
   -----------------
   */

  var regionTable : RegionTable =
    DocTable<RegionId, RegionDoc, RegionInfo>(
    0,
    func(x:RegionId):RegionId{x+1},
    func(x:RegionId,y:RegionId):Bool{x==y},
    idHash,
    func(doc:RegionDoc):RegionInfo = shared {
      id=doc.id;
      short_name=doc.short_name;
      description=doc.description;
    },
    func(info:RegionInfo):?RegionDoc = ?(new {
      id=info.id;
      short_name=info.short_name;
      description=info.description;
    }),
  );

  /**
   `produceTable`
   -----------------
   */

  var produceTable : ProduceTable =
    DocTable<ProduceId, ProduceDoc, ProduceInfo>(
    0,
    func(x:ProduceId):ProduceId{x+1},
    func(x:ProduceId,y:ProduceId):Bool{x==y},
    idHash,
    func(doc:ProduceDoc):ProduceInfo = shared {
      id=doc.id;
      short_name=doc.short_name;
      description=doc.description;
      grade=doc.grade;
    },
    func(info:ProduceInfo):?ProduceDoc = ?(new {
      id=info.id;
      short_name=info.short_name;
      description=info.description;
      grade=info.grade;
    }),
  );

  /**
   `inventoryTable`
   ---------------
   */

  var inventoryTable : InventoryTable =
    DocTable<InventoryId, InventoryDoc, InventoryInfo>(
    0,
    func(x:InventoryId):InventoryId{x+1},
    func(x:InventoryId,y:InventoryId):Bool{x==y},
    idHash,
    func(doc:InventoryDoc):InventoryInfo = shared {
      id=doc.id;
      produce=doc.produce.id;
      producer=doc.producer;
      quantity=doc.quantity;
      ppu=doc.ppu;
      start_date=doc.start_date;
      end_date=doc.end_date;
      comments=doc.comments;
    },
    func(info:InventoryInfo):?InventoryDoc = {
      // validate the info's producer and produce ids
      switch (producerTable.getDoc(info.producer),
              produceTable.getDoc(info.produce)) {
        case (?producerDoc, ?produceDoc) {
               ?(new {
                   id=info.id;
                   produce=produceDoc;
                   producer=producerDoc.id;
                   quantity=info.quantity;
                   ppu=info.ppu;
                   start_date=info.start_date;
                   end_date=info.end_date;
                   comments=info.comments;
                 })
             };
        case _ {
               null
             }
      }}
    );

  /**
   `reservedInventoryTable`
   ---------------------------
   */

  var reservedInventoryTable : ReservedInventoryTable =
    DocTable<ReservedInventoryId, ReservedInventoryDoc, ReservedInventoryInfo>(
    0,
    func(x:ReservedInventoryId):ReservedInventoryId{x+1},
    func(x:ReservedInventoryId,y:ReservedInventoryId):Bool{x==y},
    idHash,
    func(doc:ReservedInventoryDoc):ReservedInventoryInfo = shared {
      id=doc.id;
      item=doc.item.id;
      retailer=doc.retailer
    },
    func(info:ReservedInventoryInfo):?ReservedInventoryDoc = {
      // validate the info's item id
      switch (inventoryTable.getDoc(info.id),
              retailerTable.getDoc(info.retailer)) {
        case (?item, ?_) {
               ?(new {
                   id=info.id;
                   item=item:InventoryDoc;
                   retailer=info.retailer;
                 })
             };
        case _ {
               null
             }
      }}
    );


  /**
   `producerTable`
   -----------------
   */

  var producerTable : ProducerTable =
    DocTable<ProducerId, ProducerDoc, ProducerInfo>(
    0,
    func(x:ProducerId):ProducerId{x+1},
    func(x:ProducerId,y:ProducerId):Bool{x==y},
    idHash,
    func(doc:ProducerDoc):ProducerInfo = shared {
      id=doc.id;
      short_name=doc.short_name;
      description=doc.description;
      region=doc.region.id;
      inventory=[];
      reserved=[];
    },
    func(info:ProducerInfo):?ProducerDoc =
      switch (regionTable.getDoc(info.region)) {
        case (?regionDoc) {
               ?(new {
                   id=info.id;
                   short_name=info.short_name;
                   description=info.description;
                   region=regionDoc;
                   inventory=inventoryTable.empty();
                   reserved=reservedInventoryTable.empty();
                 }
               )};
        case (null) {
               null
             };
      }
    );

  /**
   `transporterTable`
   -----------------
   */

  var transporterTable : TransporterTable =
    DocTable<TransporterId, TransporterDoc, TransporterInfo> (
      0,
      func(x:TransporterId):TransporterId{x+1},
      func(x:TransporterId,y:TransporterId):Bool{x==y},
      idHash,
      func(doc:TransporterDoc):TransporterInfo = shared {
        id=doc.id;
        short_name=doc.short_name;
        description=doc.description;
        routes=[];
        reserved=[];
      },
      func(info:TransporterInfo):?TransporterDoc =
        ?(new {
            id=info.id;
            short_name=info.short_name;
            description=info.description;
            routes=routeTable.empty();
            reserved=reservedRouteTable.empty();
          })
    );

  /**
   `retailerTable`
   -----------------
   */

  var retailerTable : RetailerTable =
    DocTable<RetailerId, RetailerDoc, RetailerInfo>(
      0,
      func(x:RetailerId):RetailerId{x+1},
      func(x:RetailerId,y:RetailerId):Bool{x==y},
      idHash,
      func(doc:RetailerDoc):RetailerInfo = shared {
        id=doc.id;
        short_name=doc.short_name;
        description=doc.description;
        region=doc.region.id;
        reserved_routes=[];
        reserved_items=[];
      },
      func(info:RetailerInfo):?RetailerDoc {
        switch (regionTable.getDoc(info.region))
        {
        case (?regionDoc) {
               ?(new {
                   id=info.id;
                   short_name=info.short_name;
                   description=info.description;
                   region=regionDoc;
                   reserved=null;
                 }
               )};
        case (null) { null };
        }}
    );

  /**
   `routeTable`
   ----------------
   */

  var routeTable : RouteTable =
    DocTable<RouteId, RouteDoc, RouteInfo> (
      0,
      func(x:RouteId):RouteId{x+1},
      func(x:RouteId,y:RouteId):Bool{x==y},
      idHash,
      func(doc:RouteDoc):RouteInfo = shared {
        id=doc.id;
        transporter=doc.transporter;
        truck_type=(truckTypeTable.getInfoOfDoc())(doc.truck_type);
        start_region=doc.start_region.id;
        end_region=doc.end_region.id;
        start_date=doc.start_date;
        end_date=doc.end_date;
        cost=doc.cost;
      },
      func(info:RouteInfo):?RouteDoc {
        switch (transporterTable.getDoc(info.transporter),
                truckTypeTable.getDoc(info.truck_type.id),
                regionTable.getDoc(info.start_region),
                regionTable.getDoc(info.end_region))
        {
        case (?_, ?truckType, ?startRegion, ?endRegion) {
                 ?(new {
                     id=info.id;
                     transporter=info.transporter;
                     truck_type=truckType;
                     start_region=startRegion;
                     end_region=endRegion;
                     start_date=info.start_date;
                     end_date=info.end_date;
                     cost=info.cost;
                   })
               };
          case _ { null }
        }}
    );

  /**
   `reservedRouteTable`
   ----------------
   */

  var reservedRouteTable : ReservedRouteTable =
    DocTable<ReservedRouteId, ReservedRouteDoc, ReservedRouteInfo>(
    0,
    func(x:ReservedRouteId):ReservedRouteId{x+1},
    func(x:ReservedRouteId,y:ReservedRouteId):Bool{x==y},
    idHash,
    func(doc:ReservedRouteDoc):ReservedRouteInfo = shared {
      id=doc.id;
      route=doc.route.id;
      retailer=doc.retailer
    },
    func(info:ReservedRouteInfo):?ReservedRouteDoc = {
      // validate the info's item id
      switch (routeTable.getDoc(info.id),
              retailerTable.getDoc(info.retailer)) {
        case (?route, ?_) {
               ?(new {
                   id=info.id;
                   route=route:RouteDoc;
                   retailer=info.retailer;
                 })
             };
        case _ {
               null
             }
      }}
    );


  /**

   Indexing by `RegionId`
   =====================================

   For efficient joins, we need some extra indexing.

   Regions as keys in special global maps
   ---------------------------------------
   - inventory (across all producers) keyed by producer region
   - routes (across all transporters) keyed by source region
   - routes (across all transporters) keyed by destination region

   Routes by region
   ----------------------------

   the actor maintains a possibly-sparse 3D table mapping each
   region-region-routeid triple to zero or one routes.  First index
   is destination region, second index is source region; this 2D
   spatial coordinate gives all routes that go to that destination
   from that source, keyed by their unique route ID, the third
   coordinate of the mapping.

   */

  private var routesByDstSrcRegions : ByRegionsRouteMap = null;

  /**
   Inventory by region
   ----------------------------

   the actor maintains a possibly-sparse 3D table mapping each
   sourceregion-producerid-inventoryid triple to zero or one
   inventory items.  The 1D coordinate sourceregion gives all of the
   inventory items, by producer id, for this source region.

  */

  private var inventoryByRegion : ByRegionInventoryMap = null;


  /**

   Future work: Indexing by time
   --------------------------------
   For now, we won't try to index based on days.

   If and when we want to do so, we would like to have a spatial
   data structure that knows about each object's "interval" in a
   single shared dimension (in time):

   - inventory, by availability window (start day, end day)
   - routes, by transport window (departure day, arrival day)

   */

  /**

   PESS Behavior: message-response specifications
   ======================================================

   As explained in the `README.md` file, this actor also gives a
   behavioral spec of the exchange's semantics, by giving a prototype
   implementation of this behavior (and wrapped trivially by `Server`).

   The functional behavior of this interface, but not implementation
   details, are part of the formal PESS.

   */



  /**

   `Produce`-oriented operations
   ==========================================

   */


  /**
   `produceMarketInfo`
   ---------------------------
   The last sales price for produce within a given geographic area; null region id means "all areas."
   */
  produceMarketInfo(id:ProduceId, reg:?RegionId) : ?[ProduceMarketInfo] {
    // xxx aggregate
    null
  };

  /**

   `Producer`-facing operations
   ==========================================

   */


  /**
   // `producerAllInventoryInfo`
   // ---------------------------
   */
  producerAllInventoryInfo(id:ProducerId) : ?[InventoryInfo] {
    let doc = switch (producerTable.getDoc(id)) {
      case null { return null };
      case (?doc) { doc };
    };
    ?Map.toArray<InventoryId,InventoryDoc,InventoryInfo>(
      doc.inventory,
      func (_:InventoryId,doc:InventoryDoc):[InventoryInfo] =
        [inventoryTable.getInfoOfDoc()(doc)]
    )
  };

  /**
   `producerAddInventory`
   ---------------------------

  */
  producerAddInventory(
    id_        : ProducerId,
    produce_   : ProduceId,
    quantity_  : Quantity,
    ppu_       : Price,
    start_date_: Date,
    end_date_  : Date,
    comments_  : Text,
  ) : ?InventoryId
  {
    /** The model adds inventory and maintains secondary indicies as follows: */

    /**- Validate these ids; fail fast if not defined: */
    let oproducer : ?ProducerDoc = producerTable.getDoc(id_);
    let oproduce  : ?ProduceDoc  = produceTable.getDoc(produce_);
    let (producer, produce) = {
      switch (oproducer, oproduce) {
      case (?producer, ?produce) (producer, produce);
      case _ { return null };
      }};

    /**- Create the inventory item document: */
    let (_, item) = {
      switch (inventoryTable.addInfo(
                func(inventoryId:InventoryId):InventoryInfo{
        shared {
          id        = id_       :InventoryId;
          produce   = produce_  :ProduceId;
          producer  = produce_  :ProducerId;
          quantity  = quantity_ :Quantity;
          ppu       = ppu_      :Price;
          start_date=start_date_:Date;
          end_date  =end_date_  :Date;
          comments  =comments_  :Text;
        };
      })) {
      case (?item) { item };
      case (null) { assert false ; return null };
      }
    };

    /**- Update the producer's inventory collection to hold the new inventory document: */
    let updatedInventory = 
      Map.insertFresh<InventoryId, InventoryDoc>(
        producer.inventory,
        keyOf(item.id),
        idIsEq,
        item
      );

    /**- Update the producer document; xxx more concise syntax for functional record updates would be nice: */
    let _ = producerTable.updateDoc(
      producer.id,
      new {
        id = producer.id;
        short_name = producer.short_name;
        description = producer.description;
        region = producer.region;
        reserved = producer.reserved;
        inventory = updatedInventory;
      });

    /**- Update inventoryByRegion mapping: */
    inventoryByRegion :=
    Map.insertFresh2D<RegionId, ProducerId, InventoryMap>(
      inventoryByRegion,
      // key1: region id of the producer
      keyOf(producer.region.id), idIsEq,
      // key2: producer id */
      keyOf(producer.id), idIsEq,
      // value: updated inventory table
      updatedInventory,
    );

    ?item.id
  };

  /**
   `producerRemInventory`
   ---------------------------


   **Implementation summary:**

    - remove from the inventory in inventory table; use `Trie.removeThen`
    - if successful, look up the producer ID; should not fail; `Trie.find`
    - update the producer, removing this inventory; use `Trie.{replace,remove}`
    - finally, use producer's region to update inventoryByRegion table,
      removing this inventory item; use `Trie.remove2D`.
   */
  producerRemInventory(id:InventoryId) : ?() {
    // xxx rem
    null
  };

  /**
   `producerReservations`
   ---------------------------

   */
  producerReservations(id:ProducerId) : ?[ReservedInventoryInfo] {
    let doc = switch (producerTable.getDoc(id)) {
      case null { return null };
      case (?doc) { doc };
    };
    ?Map.toArray<ReservedInventoryId,
                 ReservedInventoryDoc,
                 ReservedInventoryInfo>(
      doc.reserved,
      func (_:ReservedInventoryId,
            doc:ReservedInventoryDoc):
        [ReservedInventoryInfo]
        =
        [reservedInventoryTable.getInfoOfDoc()(doc)]
    )
  };


   /**
   `Transporter`-facing operations
   =================
   */


  /**
   `transporterAddRoute`
   ---------------------------
  */
  transporterAddRoute(
    id_:             TransporterId,
    start_region_id: RegionId,
    end_region_id:   RegionId,
    start_date_:     Date,
    end_date_:       Date,
    cost_:           Price,
    trucktype_id:    TruckTypeId
  ) : ?RouteId {
    /** The model adds inventory and maintains secondary indicies as follows: */

    /**- Validate these ids; fail fast if not defined: */
    let otransporter : ?TransporterDoc = transporterTable.getDoc(id_);
    let orstart      : ?RegionDoc  = regionTable.getDoc(start_region_id);
    let orend        : ?RegionDoc  = regionTable.getDoc(end_region_id);
    let otrucktype   : ?TruckTypeDoc  = truckTypeTable.getDoc(trucktype_id);
    let (transporter, start_region_, end_region_, truck_type_) = {
      switch (otransporter, orstart, orend, otrucktype) {
      case (?x1, ?x2, ?x3, ?x4) (x1, x2, x3, x4);
      case _ { return null };
      }};

    /**- Create the route item document: */
    let (_, route) = routeTable.addDoc(
      func(routeId:RouteId):RouteDoc{
        new {
          id= routeId;
          transporter=id_;
          truck_type=truck_type_;
          start_date=start_date_;
          end_date=end_date_;
          start_region=start_region_;
          end_region=end_region_;
          cost=cost_;
        };
      });
    
    /**- Update the **transporter's routes collection** to hold the new route document: */
    let updatedRoutes = 
      Map.insertFresh<RouteId, RouteDoc>(
        transporter.routes,
        keyOf(route.id),
        idIsEq,
        route
      );

    /**- Update the transporter document; xxx more concise syntax for functional record updates would be nice: */
    let _ = transporterTable.updateDoc(
      transporter.id, 
      new {
        id = transporter.id;
        short_name = transporter.short_name;
        description = transporter.description;
        reserved = transporter.reserved;
        routes = updatedRoutes;
      });

    /**- Update the [`routesByDstSrcRegions` mapping](#routes-by-region) using the route's regions and id */
    routesByDstSrcRegions :=
    Map.insertFresh3D<RegionId, RegionId, RouteId, RouteDoc>(
      routesByDstSrcRegions,
      keyOf(end_region_.id), idIsEq,
      keyOf(start_region_.id), idIsEq,
      keyOf(route.id), idIsEq,
      route
    );

    ?route.id
  };

  /**
   `transporterRemRoute`
   ---------------------------


   **Implementation summary:**

    - remove from the inventory in inventory table; use `Trie.removeThen`
    - if successful, look up the producer ID; should not fail; `Trie.find`
    - update the transporter, removing this inventory; use `Trie.{replace,remove}`
    - finally, use route info to update the routesByRegion table,
      removing this inventory item; use `Trie.remove2D`.
   */
  transporterRemRoute(id:RouteId) : ?() {
    // xxx rem
    null
  };

  /**
   `transporterAllRouteInfo`
   ---------------------------
   */
  transporterAllRouteInfo(id:RouteId) : ?[RouteInfo] {
    let doc = switch (transporterTable.getDoc(id)) {
      case null { return null };
      case (?doc) { doc };
    };
    ?Map.toArray<RouteId,
                 RouteDoc,
                 RouteInfo>(
      doc.routes,
      func (_:RouteId,
            doc:RouteDoc):
        [RouteInfo]
        =
        [routeTable.getInfoOfDoc()(doc)]
    )
  };

  /**
   `transporterReservationInfo`
   ---------------------------

   */
  transporterAllReservationInfo(id:TransporterId) : ?[ReservedRouteInfo] {
    let doc = switch (transporterTable.getDoc(id)) {
      case null { return null };
      case (?doc) { doc };
    };
    ?Map.toArray<ReservedRouteId,
                 ReservedRouteDoc,
                 ReservedRouteInfo>(
      doc.reserved,
      func (_:ReservedRouteId,
            doc:ReservedRouteDoc):
        [ReservedRouteInfo]
        =
        [reservedRouteTable.getInfoOfDoc()(doc)]
    )
  };


  /**
   `Retailer`-facing operations
   ====================
   */


  /**
   `retailerQueryAll`
   ---------------------------

   TODO-Cursors (see above).

  */
  retailerQueryAll(id:RetailerId) : ?QueryAllResults {
    // xxx join
    null
  };

  /**
   `retailerAllReservationInfo`
   ---------------------------

   TODO-Cursors (see above).

  */
  retailerAllReservationInfo(id:RetailerId) :
    ?[(ReservedInventoryInfo,
       ReservedRouteInfo)]
  {
    let doc = switch (retailerTable.getDoc(id)) {
      case null { return null };
      case (?doc) { doc };
    };
    ?Map.toArray<ReservedInventoryId,
                 (ReservedInventoryDoc,  ReservedRouteDoc),
                 (ReservedInventoryInfo, ReservedRouteInfo)>(
      doc.reserved,
      func (_:ReservedInventoryId,
            ((idoc:ReservedInventoryDoc),
             (rdoc:ReservedRouteDoc)))
            :
            [(ReservedInventoryInfo,
              ReservedRouteInfo)]
        =
        [(reservedInventoryTable.getInfoOfDoc()(idoc),
          reservedRouteTable.getInfoOfDoc()(rdoc))]
    )
  };

  /**
   `retailerQueryDates`
   ---------------------------

   Retailer queries available produce by delivery date range; returns
   a list of inventory items that can be delivered to that retailer's
   geography within that date.

   ```
   let jt = (joinTablesConditionally
               (routesByDstSrcRegionTable (retailer region))
               inventoryByRegionTable
               filterByDateConstraints
            );
   ```

   */
  retailerQueryDates(
    id:RetailerId,
    begin:Date,
    end:Date
  ) : ?[InventoryInfo]
  {
    // xxx join+filter
    
    null
  };

  /**
   `retailerReserve`
   ---------------------------
  */
  retailerReserve(
    id:RetailerId,
    inventory:InventoryId,
    route:RouteId) : ?(ReservedRouteId, ReservedInventoryId)
  {
    // xxx add/rem
    null
  };

  /**
   `retailerReserveCheapest`
   ---------------------------

   Like `retailerReserve`, but chooses cheapest choice among all
   feasible produce inventory items and routes, given a grade,
   quant, and delivery window.

   ?? This may be an example of what Mack described to me as
   wanting, and being important -- a "conditional update"?

  */
  retailerReserveCheapest(
    id:RetailerId,
    produce:ProduceId,
    grade:Grade,
    quant:Quantity,
    begin:Date,
    end:Date
  ) : ?(ReservedInventoryId, ReservedRouteId)
  {
    // xxx query+add/rem
    null
  };




};
