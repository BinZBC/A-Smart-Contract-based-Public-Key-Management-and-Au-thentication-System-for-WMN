pragma solidity ^ 0.4.0;
contract Union {
	struct DomainInfo {
		address MCAddr;     //Management contract address in the domain
		string GWPK;        //Gateway’s public key
		address GWAddr;     //Gateway address
	}
	string public PK;          //public key of CA
	address public owner;      //address of creater 
	address public UC;         //this contract's address
	string[] public domain ;
	uint public domainNum;
	constructor(string _PK)public {
		owner = msg.sender;
		PK = _PK;
		UC = this;
		domain.length=0;
		domainNum=0;
	}
	
	mapping(string => DomainInfo) DomainList;  //map ID => DomainInfo for storing domain list

	
	event Add_Domain(string _ID, address _MCAddr, string _GWPK, address _GWAddr);
	/*register an manager,add the information to DomainInfo list.*/
	function Add_manager(string _ID, address _MCAddr, string _GWPK, address _GWAddr)public {
		if (msg.sender != owner)
			throw;
		//no duplicate check	
		DomainList[_ID].MCAddr = _MCAddr;
		DomainList[_ID].GWPK = _GWPK;
		DomainList[_ID].GWAddr = _GWAddr;
		domain.push(_ID);
		domainNum++;
		emit Add_Domain(_ID, _MCAddr, _GWPK, _GWAddr);
	}
 /*get MC address of a domain*/
	function getMCAddr(string _ID)public constant returns(address _scAddr) {
		_scAddr = DomainList[_ID].MCAddr;
	}

	function getGWAddr(string _ID)public constant returns(address _GWAddr) {
		_GWAddr = DomainList[_ID].GWAddr;
	}

}
