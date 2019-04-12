pragma solidity ^ 0.4.0;
contract AccessControl {
  
  address public owner;
  
  event ReturnAccessResult(
    string _from,
    uint _err,
    bool _result,
    uint _time);
  
  struct Misbehavior {
    string misbehavior;  //misbehavior
    uint time;           //time of the misbehavior occured
    uint penalty;       //penalty opposed to the client (number of minutes blocked)
  }
  
  /*As solidity cannot allow dynamically-sized value as the Key, we use the fixed-szie byte32 type as the keytype*/
  mapping(bytes32 => Misbehavior[])public MisbehaviorList;  //mapping clientID => Misbehavior[] for recording the client's misbehaviors
  
  struct AccessReport {
    uint time;    //Time of Last Request
    bool result;  //last access result
    uint8 err;    //last err code
  }
 
  struct AccessReports { 
    bool isValued;   //for duplicate check
    string DomainID; //Domain’s identification
    uint Num;        //Number of access
    uint NoFR;       //Number of frequent Requests in a short period of time
    uint NoB;        //Times of blocked
    uint ToUnB;      //time when the client is unblocked (0 if unblocked; otherwise,blocked)
    AccessReport[]ar;//access records    
  }
  
  /*get access report*/
  function getAccessReport(string _ID,uint index)public constant returns(uint time, bool result,uint8 err){
      bytes32 _ID32 = stringToBytes32(_ID);
      AccessReport storage ar=AccessClientL[_ID32].ar[index];
      return (ar.time,ar.result,ar.err);
  }
 
  mapping(bytes32 => AccessReports)public AccessClientL;  //mapping clientID =>AccessReports for storing access records.
  
  constructor()public {
    owner = msg.sender;
  }
  
  event isCalled(address _from, uint _time, uint _penalty);
  
  /*report misbehavio*/
  function misbehaviorRe(string _ID,  uint _time, string _misbehavior,uint penalty)public returns(bool) {
    bytes32 _ID32 = stringToBytes32(_ID);
    AccessClientL[_ID32].NoB+=1;
    MisbehaviorList[_ID32].push(Misbehavior(_misbehavior, _time, penalty));
    emit isCalled(msg.sender, _time, penalty);
    return true;
  }
  
  /*report access record */
  function ARAdd(string _ID, uint _time, bool _result, uint8 _err)public returns(uint8) {
    require(msg.sender == owner);
    bytes32 _ID32 = stringToBytes32(_ID);    
    AccessClientL[_ID32].ar.push(AccessReport(_time, _result, _err));
    AccessClientL[_ID32].Num = AccessClientL[_ID32].Num + 1;
  }
   
   /*set the AccessClientL list*/
   function setACL(string _ID, uint ToUnB,uint NoFR, uint time, uint8 errorcode, bool result)public returns(bool) {
       bytes32 _ID32 = stringToBytes32(_ID);
       AccessClientL[_ID32].ToUnB=ToUnB;
       AccessClientL[_ID32].NoFR=NoFR; 
       ARAdd( _ID,time, result,errorcode);
       emit ReturnAccessResult( _ID,errorcode,result, time);
   }
  
   /*initialize the AccessClientL list*/
   function ACLInite(string _DID,string _ID, uint time, uint8 errorcode, bool result)public returns(bool) {
       bytes32 _ID32 = stringToBytes32(_ID); 
       AccessClientL[_ID32].isValued = true;
       AccessClientL[_ID32].DomainID = _DID;
       AccessClientL[_ID32].NoFR = 0;
       AccessClientL[_ID32].Num = 0;
       AccessClientL[_ID32].ToUnB = 0;
       AccessClientL[_ID32].NoB = 0;
       ARAdd( _ID,time,  result,errorcode);
       emit ReturnAccessResult( _ID,errorcode,result, time);
   }
    
   /*get latest misbehavior of a client*/  
  function getLatestMisbehavior(string _ID)public constant returns(string _misbehavior, uint _time) {
    bytes32 _ID32 = stringToBytes32(_ID);
    uint latest = MisbehaviorList[_ID32].length - 1;
    _misbehavior = MisbehaviorList[_ID32][latest].misbehavior;
    _time = MisbehaviorList[_ID32][latest].time;
  }
  
  /*get unblocked time of a client*/ 
  function getToUnB(string _ID)public constant returns(uint _penalty, uint _ToUnB) {
    bytes32 _ID32 = stringToBytes32(_ID);
    _ToUnB = AccessClientL[_ID32].ToUnB;
    uint l = MisbehaviorList[_ID32].length;
    _penalty = MisbehaviorList[_ID32][l - 1].penalty;
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
