const Web3 = require('web3');
const web3 = new Web3(Web3.givenProvider || "http://127.0.0.1:8545");
var path = require('path');
var fs = require('fs');

var UCAddr = '0x059DFCBd263b09515872C2841A60bc99E00B5aC1';
var file = path.join(__dirname, 'Union.json');

var readFile = function (fileName) {
	return new Promise((resolve, reject) => {
		fs.readFile(fileName, (err, data) => {
			if (!err) {
				resolve(data);
			} else {
				reject(err);
			}
		});
	});
}

var contract = async function (file, Addre) {//create a contract using ABI file and contract address
	var data = await readFile(file);
	js = JSON.parse(data.toString());
	var UC = new web3.eth.Contract(js.abi, Addre);
	return UC;
};

var events = [[], []];//store all events in all domian
var UC;
var innit = async function () { //create the UC 
	UC = await contract(file, UCAddr);
}
innit();

var domainNum = 0;
var MC = [];//store all domain MC
var DID = []; //store all domain ID
var monitor = async function () {
	let domainNum1 = await UC.methods.domainNum().call();
	file = path.join(__dirname, 'Management.json');
	if (domainNum1 != domainNum) //new domain 
		for (let i = domainNum; i < domainNum1; i++) {
			DID.push(await UC.methods.domain(i).call());
			let McAddr = (await UC.methods.getMCAddr(DID[i]).call());
			MC.push(await contract(file, McAddr));
		}
	domainNum = domainNum1;
	
	for (let i = 0; i < domainNum; i++) {//Iterate through all the domain
		await MC[i].getPastEvents('allEvents', {
			fromBlock: 0,
			toBlock: 'latest'
		}).then(async(results) => {
			console.log(events[i].length);
			if (events[i].length == results.length) {
				console.log("No new event");
			} else {//new events occur 
				results.splice(0, events[i].length); 
				for (result of results) {
					if (result.event == 'RouterADD') {
						console.log("transactionHash: " + result.transactionHash);
						console.log("Domain " + DID[i] + ' adds router ' + result.returnValues._user + ", its PK is " + result.returnValues._PK + ',\nand its address is ' + result.returnValues._owner);
						let id32 = await MC[i].methods.stringToBytes32(result.returnValues._user).call();
						let router = await MC[i].methods.routerL(id32).call();
						console.log(router);
						console.log('\n');
					}
					if (result.event == 'ClientADD') {
						console.log("transactionHash: " + result.transactionHash);
						console.log("Domain " + DID[i] + ' adds client ' + result.returnValues._user + ", its PK is " + result.returnValues._PK);
						let id32 = await MC[i].methods.stringToBytes32(result.returnValues._user).call();
						let router = await MC[i].methods.clientL(id32).call();
						console.log(router);
						console.log('\n');
					}
					if (result.event == 'RouterUPDATE') {
						console.log("transactionHash: " + result.transactionHash);
						console.log("Domain " + DID[i] + "'s router " + result.returnValues._user + " updates its PK to " + result.returnValues._PK + '.\n');
						let id32 = await MC[i].methods.stringToBytes32(result.returnValues._user).call();
						let router = await MC[i].methods.routerL(id32).call();
						console.log(router);
						console.log('\n');
					}
					if (result.event == 'ClientUPDATE') {
						console.log("transactionHash: " + result.transactionHash);
						console.log("Domain " + DID[i] + "'s client " + result.returnValues._user + " updates its PK to " + result.returnValues._PK + '.\n');
						let id32 = await MC[i].methods.stringToBytes32(result.returnValues._user).call();
						let router = await MC[i].methods.clientL(id32).call();
						console.log(router);
						console.log('\n');
					}
					if (result.event == 'RouterREVOCATE') {
						console.log("transactionHash: " + result.transactionHash);
						console.log("Domain " + DID[i] + "'s router " + result.returnValues._user + "is REVOCATE.\n");
						console.log('\n');
					}
					if (result.event == 'ClientREVOCATE') {
						console.log("transactionHash: " + result.transactionHash);
						console.log("Domain " + DID[i] + "'s client " + result.returnValues._user + "is REVOCATE.\n");
						console.log('\n');
					}
					if (result.event == 'RouterEXPIRED') {
						console.log("transactionHash: " + result.transactionHash);
						console.log("The PK " + result.returnValues._PK + ' of Router ' + result.returnValues._ID + " of Domain " + DID[i] + ' is EXPIRED. \n ');
						console.log('\n');
					}
					if (result.event == ' ClientEXPIRED ') {
						console.log("transactionHash: " + result.transactionHash);
						console.log("The PK " + result.returnValues._PK + ' of Client ' + result.returnValues._ID + " of Domain " + DID[i] + ' is EXPIRED. \n ');
						console.log('\n');
					}
				}
				events[i] = events[i].concat(results);//add new events to events
			}
		}); ;
	}

};


var CronJob = require('cron').CronJob;
/*checke events every 30s*/
new CronJob('*/30 * * * * *', monitor, null, true, 'America/Los_Angeles');
