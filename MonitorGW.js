const Web3 = require('web3');
const web3 = new Web3(Web3.givenProvider || "http://10.114.1.58:8545");
var path = require('path');
var fs = require('fs');

var AccAddr = '0x254C3a0d8B45fEEbB4979fC739bFcE2086f14CC1';
var R1Addr = '0xc90C5109Eab3c93CC669746f8656CBFEB8AEB5cC';
var MCAddr = '0xf4788cEaFeB9C8a6D432E7281aA355E29C778637';

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

Array.prototype.remove = function (val) {
	var index = this.indexOf(val);
	if (index > -1) {
		this.splice(index, 1);
	}
};

var contract = async function (file, Addre) {
	var data = await readFile(file);
	js = JSON.parse(data.toString());
	var UC = new web3.eth.Contract(js.abi, Addre);
	return UC;
};
var events = [];
var user = [];

var monitor = async function () {
	let file = path.join(__dirname, 'Management.json');
	var MC = await contract(file, MCAddr);

	await MC.getPastEvents('allEvents', {
		fromBlock: 0,
		toBlock: 'latest'
	}, async(error, results) => {
		if (events.length == results.length) {
			console.log("No new event");
		} else {
			results.splice(0, events.length);
			for (result of results) {
				if (result.event == 'RouterADD') {
					console.log("transactionHash: " + result.transactionHash);
					console.log('Add router ' + result.returnValues._user + ", its PK is " + result.returnValues._PK + ',\nand its address is ' + result.returnValues._owner);
					user.push(result.returnValues._user);
					console.log('\n');
				}
				if (result.event == 'ClientADD') {
					console.log("transactionHash: " + result.transactionHash);
					console.log('Adds client ' + result.returnValues._user + ", its PK is " + result.returnValues._PK);
					user.push(result.returnValues._user);

					console.log('\n');
				}
				if (result.event == 'RouterUPDATE') {
					console.log("transactionHash: " + result.transactionHash);
					console.log("Router " + result.returnValues._user + " updates its PK to " + result.returnValues._PK + '.\n');

					console.log('\n');
				}
				if (result.event == 'ClientUPDATE') {
					console.log("transactionHash: " + result.transactionHash);
					console.log("Client " + result.returnValues._user + " updates its PK to " + result.returnValues._PK + '.\n');

					console.log('\n');
				}
				if (result.event == 'RouterREVOCATE') {
					console.log("transactionHash: " + result.transactionHash);
					console.log("Router " + result.returnValues._user + "is REVOCATE.\n");
					user.remove(result.returnValues._user);
					console.log('\n');
				}
				if (result.event == 'ClientREVOCATE') {
					console.log("transactionHash: " + result.transactionHash);
					console.log("Client " + result.returnValues._user + "is REVOCATE.\n");
					user.remove(result.returnValues._user);
					console.log('\n');
				}
				if (result.event == 'RouterEXPIRED') {
					console.log("transactionHash: " + result.transactionHash);
					console.log("The PK " + result.returnValues._PK + ' of Router ' + result.returnValues._ID + ' is EXPIRED. \n ');
					console.log('\n');
				}
				if (result.event == 'ClientEXPIRED') {
					console.log("transactionHash: " + result.transactionHash);
					console.log("The PK " + result.returnValues._PK + ' of Client ' + result.returnValues._ID + ' is EXPIRED. \n ');
					console.log('\n');
				}
			}
			events = events.concat(results);
		}
	});
	for (u of user) {
		var time = parseInt(new Date().getTime() / 1000);
		let id32 = await MC.methods.stringToBytes32(u).call();
		let router = await MC.methods.routerL(id32).call();
		if (router.register_ack == 0)
			router = await MC.methods.clientL(id32).call();
		if (time >= router.Outtime && router.Attr == 0) {
			console.log(u + ' is EXPIRED');
			MC.methods.Time(u).send({
				from: R1Addr,
				gas: 40000000
			});
		}
	};

};
var CronJob = require('cron').CronJob;
new CronJob('*/30 * * * * *', monitor, null, true, 'America/Los_Angeles');
