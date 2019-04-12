pragma solidity ^ 0.4.22;

contract Management {
	struct manager {
		string managerID;             //Manager’s identification.
		string DID;                   //Domain’s identification.
		string managerPK;             //Manager’s public key.
		uint T_renew;                 //Public key update interval.
		address managerAddr;          //Account address of manager.
	}
	manager public Mgr;
	enum ATTR {
		registed,
		malicious,
		expired
	}

	struct router {
		uint8 register_ack;             //for register check.
		string routerPK;                //Router’s public key.
		address routerAddr;             //Router’s address.
		address ACCAddr;                //Address of access control contract.
		uint16 acceptNum;               //Number of accept nodes, default is 0
		uint16 Trustlevel;              //Node trust level.
		uint Outtime;                   //Router public key expiration time.
		ATTR Attr;                      //Node public key attribute.
	}
	mapping(string =>mapping(string => bool))  AcceptL;  //mapping (routerID1, routerID2) => bool for checking if routerID2 accepting routerID1.
  
	function getAcceptL(string u1,string u2)public constant  returns(bool){
	    return AcceptL[u1][u2];
	}
  
	struct client {
		uint8 register_ack;           //for register check.         
		string clientPK;              //Client’s public key.
		string routerID;              //Identification of the router adding this client.
		uint Outtime;                 //Client public key expiration time.
		uint CoN;                     //Number of connection routers.
		uint8 maliciousRN;             //Number of malicious reports.
		ATTR Attr;                    //Node public key attribute.
	}
	mapping(string =>mapping(string => bool))routerConL;   //mapping (clienID, routerID) => bool for checking if client connecting router.
  
	function getrouterCon(string u1,string u2)public constant returns(bool){
	    return routerConL[u1][u2];
	}
	struct malicious_node {
		uint16 Acc_num;              //Number of accusers.
		uint8 Rev;                   //Revocation confirmation.
	}
	mapping(string =>mapping(string => bool))AccL;   //mapping (routerID1, routerID1) => bool for checking if router2 accusing router1.
	
  function getAccL(string u1,string u2)public constant  returns(bool){
	    return AccL[u1][u2];
	}
	mapping(address => string)node;
	uint16 public routerNum;       //The number of registered mesh routers in the domain.
	uint16 public clientNum;       //The number of registered mesh clients in the domain.
  	/*As solidity cannot allow dynamically-sized value as the Key, we use the fixed-szie byte32 type as the
	keytype*/
	mapping(bytes32 => router)public routerL;       //mapping (routerID) => router for storing router information.
	mapping(bytes32 => malicious_node)public ML;     //mapping (routerID) => malicious_node for storing malicious router information.
	mapping(bytes32 => client)public clientL;       //mapping (clientID) => client for storing client information.
	
  event RouterADD(address indexed _owner, string _user, string _PK);
	event ClientADD(string _user, string _PK);
	event RouterUPDATE(address indexed _owner, string _user, string _PK);
	event ClientUPDATE(string _user, string _PK);
	event RouterREVOCATE(string _user);
	event ClientREVOCATE(string _user);
	event RouterEXPIRED(string _ID, string _PK);
	event ClientEXPIRED(string _ID, string _PK);

	constructor(string _ID, string _DID, string pk)public { 
		Mgr.managerID = _ID;
		Mgr.DID = _DID;
		Mgr.managerPK = pk;
		Mgr.managerAddr = msg.sender;
		Mgr.T_renew = 30;
		routerNum = 0;
		clientNum = 0;
	}
/*add the a router to the router list routerL*/
	function routerAdd(address addr, string _ID, string _pk, address _acc)public {
	/*the caller must be manager*/
		require(msg.sender == Mgr.managerAddr);
		bytes32 _ID32 = stringToBytes32(_ID);
		require(routerL[_ID32].register_ack == 0);
		routerL[_ID32].routerPK = _pk;
		routerL[_ID32].Attr = ATTR.registed;
		routerL[_ID32].acceptNum = 0;
		routerL[_ID32].Outtime = now + Mgr.T_renew * 1 minutes;
		routerL[_ID32].register_ack = 1;
		routerL[_ID32].routerAddr = addr;
		routerL[_ID32].ACCAddr = _acc;
		node[addr] = _ID;
		emit RouterADD(addr, _ID, _pk);
		routerNum += 1;
	}
  
/*accept another registered router*/
	function Accept(string _ID)public {
		bytes32 _ID32 = stringToBytes32(_ID);
		/*the router must have been registered, its attribute must be registed and it is not caller*/
		require(routerL[_ID32].register_ack == 1 && routerL[_ID32].Attr == ATTR.registed&&routerL[_ID32].routerAddr!=msg.sender);
		bytes32 _ID132 = stringToBytes32(node[msg.sender]);
		/*the caller must have been registered and its attribute must be registed*/
		require(routerL[_ID132].register_ack == 1 && routerL[_ID132].Attr == ATTR.registed);
		if (AcceptL[_ID][node[msg.sender]] == false) {
			routerL[_ID32].acceptNum += 1;
			AcceptL[_ID][node[msg.sender]] = true;
			routerL[_ID32].Trustlevel = routerL[_ID32].acceptNum * 100 / (routerNum-1);
		}
	}

/*update public key of a registered router*/
	function routerUpdate(string pk)public {
		bytes32 _ID132 = stringToBytes32(node[msg.sender]);
		/*the router must have been registered and its attribute must be registed or expired*/
		require(routerL[_ID132].register_ack == 1 && (routerL[_ID132].Attr == ATTR.registed || routerL[_ID132].Attr == ATTR.expired));
		routerL[_ID132].routerPK = pk;
		if (routerL[_ID132].Attr == ATTR.expired)
			routerL[_ID132].Attr = ATTR.registed;
		routerL[_ID132].Outtime = now + Mgr.T_renew*1 minutes;
		emit RouterUPDATE(msg.sender, node[msg.sender], pk);
	}
/*accuse some router*/
	function Accuse(string _ID)public {
		bytes32 _ID132 = stringToBytes32(node[msg.sender]);
		bytes32 _ID32 = stringToBytes32(_ID);
		/*the router must have been registered and its attribute must be registed or malicious*/
		require(routerL[_ID32].register_ack == 1 && (routerL[_ID32].Attr == ATTR.registed || routerL[_ID32].Attr == ATTR.malicious));
		if (msg.sender == Mgr.managerAddr) {  //case caller is manager, the public key is revoked immediately
			delete routerL[_ID32];
			routerNum -= 1;
			//ML[_ID32].Rev = 1;
			emit RouterREVOCATE(_ID);
			/*case caller is registered router, its attribute is registed, and it has not accuse the router*/
		} else if (routerL[_ID132].register_ack == 1 && routerL[_ID132].Attr == ATTR.registed&&AccL[_ID][node[msg.sender]]==false) {
			AccL[_ID][node[msg.sender]] = true;
			ML[_ID32].Acc_num += 1;
			routerRev(_ID);
		}
	}
/*revoke the public key of a registered router and delete the router in router list routerL*/
	function routerRev(string _ID)internal {
		bytes32 _ID32 = stringToBytes32(_ID);
		if(routerNum<4)return;
		if (ML[_ID32].Acc_num >= routerNum / 2 && ML[_ID32].Acc_num < 2*routerNum/3)
			routerL[_ID32].Attr = ATTR.malicious;
		if (ML[_ID32].Acc_num >= 2 * routerNum / 3 && ML[_ID32].Rev != 1) {
			delete routerL[_ID32];
			routerNum -= 1;
			ML[_ID32].Rev = 1;
			emit RouterREVOCATE(_ID);
		}
	}
/*get the public key and attribute of some router or client*/
	function ViewPK(string _ID)constant public returns(string _pk, uint8 ack) {
		bytes32 _ID32 = stringToBytes32(_ID);
		/*the router or the client has not registered*/
		if (routerL[_ID32].register_ack == 0 && clientL[_ID32].register_ack == 0)
			return ("", 0);
		else
			if (routerL[_ID32].register_ack == 1) {  //case router
				_pk = routerL[_ID32].routerPK;
				if (routerL[_ID32].Attr == ATTR.registed)
					ack = 1;
				else if (routerL[_ID32].Attr == ATTR.malicious)
					ack = 2;
				else
					ack = 3;
			} else {  //case client
				_pk = clientL[_ID32].clientPK;
				if (clientL[_ID32].Attr == ATTR.registed)
					ack = 1;
				else if (clientL[_ID32].Attr == ATTR.malicious)
					ack = 2;
				else
					ack = 3;
			}
	}
  /*add the a client to the client list clientL*/
	function clientAdd(string _ID, string pk)public {
		bytes32 _ID32 = stringToBytes32(_ID);
		bytes32 _ID132 = stringToBytes32(node[msg.sender]);
		/*the client must have not been registered*/
		require(clientL[_ID32].register_ack == 0);
		/*the caller must have been registered and its attribute must be registed*/
		require(routerL[_ID132].register_ack == 1 && routerL[_ID132].Attr == ATTR.registed);
		clientL[_ID32].clientPK = pk;
		clientL[_ID32].Attr = ATTR.registed;
		clientL[_ID32].register_ack = 1;
		clientL[_ID32].routerID = node[msg.sender];
		clientL[_ID32].Outtime = now + Mgr.T_renew* 1 minutes;
		clientL[_ID32].maliciousRN;
		emit ClientADD(_ID, pk);
		clientNum += 1;
	}
/*update public key of a registered client*/
	function clientUpdate(string _ID, string pk)public {
		bytes32 _ID32 = stringToBytes32(_ID);
		bytes32 _ID132 = stringToBytes32(node[msg.sender]);
		/*the caller must have been registered and its attribute must be registed*/
		require(routerL[_ID132].register_ack == 1 && routerL[_ID132].Attr == ATTR.registed);
		clientL[_ID32].clientPK = pk;
		clientL[_ID32].Attr = ATTR.registed;
		clientL[_ID32].routerID = node[msg.sender];
		emit ClientUPDATE(_ID, pk);
	}
  /*revoke the public key of a registered client */
	function clientRev(string _ID)public {
		bytes32 _ID32 = stringToBytes32(_ID);
		bytes32 _IDr32 = stringToBytes32(node[msg.sender]);
		/*the caller and the client must have been registered, the client has connected the the caller */
		require(clientL[_ID32].register_ack == 1&&routerL[_IDr32].register_ack == 1);
		require(routerConL[_ID][node[msg.sender]] == true);
		clientL[_ID32].maliciousRN += 1;
		if (clientL[_ID32].maliciousRN > clientL[_ID32].CoN / 2)
			clientL[_ID32].Attr = ATTR.malicious;
		if (clientL[_ID32].maliciousRN > 2 * clientL[_ID32].CoN / 3) {
			delete clientL[_ID32];
			clientNum -= 1;
			emit ClientREVOCATE(_ID);
		}
	}
/*adds the caller (a router) to routerCon list of a client accessing it*/
	function clientCon(string _ID)public {
		bytes32 _ID32 = stringToBytes32(_ID);
		bytes32 _ID132 = stringToBytes32(node[msg.sender]);
		/*the caller and the client must have been registered, the client has not connected the the caller */
		if (routerL[_ID132].register_ack == 1 && clientL[_ID32].register_ack == 1 && routerConL[_ID][node[msg.sender]] == false) {
			routerConL[_ID][node[msg.sender]] = true;
			clientL[_ID32].CoN += 1;
		}

	}
/*check if the public key of some router or client has expired*/
	function Time(string _ID)public returns(uint256) {
		bytes32 _ID32 = stringToBytes32(_ID);
		/*the router or client must have been registered*/
		require(routerL[_ID32].register_ack == 1 || clientL[_ID32].register_ack == 1);
		/*case  router*/
		if (routerL[_ID32].register_ack == 1) {
			if (now >= routerL[_ID32].Outtime) {   //expired
				if (routerL[_ID32].Attr == ATTR.registed) //only registed router can change to expired
					routerL[_ID32].Attr = ATTR.expired;
				string memory pk = routerL[_ID32].routerPK;
				emit RouterEXPIRED(_ID, pk);
			}
		} else {    //case client similar to router
			if (now >= clientL[_ID32].Outtime) {
				if (clientL[_ID32].Attr == ATTR.registed)
					clientL[_ID32].Attr = ATTR.expired;
				pk = clientL[_ID32].clientPK;
				emit ClientEXPIRED(_ID, pk);
			}
		}
	}
  
	/*convert strings to byte32*/
  function stringToBytes32(string memory source)public constant returns (bytes32 result) {
    bytes memory tempEmptyStringTest = bytes(source);
    if (tempEmptyStringTest.length == 0) {
        return 0x0;
    }
    assembly {
        result := mload(add(source, 32))
    }
      
  }
}
