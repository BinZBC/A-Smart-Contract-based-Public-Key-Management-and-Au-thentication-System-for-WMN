const Web3 = require('web3');
const web3 = new Web3(Web3.givenProvider || "http://127.0.0.1:8545");
var path = require('path');
var fs = require('fs');


var base = 2;
var minInterval = 60;
var ThroFR = 3;
var ThroB = 3;
var interval = 5;
var ID = 'R1';

var AccAddr = '0x3733Ce226ADC217006751Fea2B06738b5180cFF5';
var UCAddre = '0xE6b0579981458d9535a617ab58F1e6e85E726ac9';
var R1Addr = "0xc90C5109Eab3c93CC669746f8656CBFEB8AEB5cC";

function misbehaviorJudge(num) {
	length = num + 1;
	n = length / interval;
	penalty = parseInt(base ** n * 10 - 10);
	return penalty;
}

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
var contract = async function (file, Addre) {
	var data = await readFile(file);
	js = JSON.parse(data.toString());
	var UC = new web3.eth.Contract(js.abi, Addre);
	return UC;
};

var currentTxHash = "";
var previousTxHash = "";

async function ACC(_ID, _DID) {
	var _time = parseInt(new Date().getTime() / 1000);
	var file = path.join(__dirname, 'Union.json');
	let UC = await contract(file, UCAddre);
	let McAddr = (await UC.methods.getMCAddr(_DID).call());
	file = path.join(__dirname, 'Management.json');
	await web3.eth.personal.unlockAccount(R1Addr, "123", 600000);
	var MC = await contract(file, McAddr);
	let ack = (await MC.methods.ViewPK(_ID).call()).ack;
	if (ack == 0) {
		console.log("Client " + _ID + " does not exists");
		return 4;
	} else {
		file = path.join(__dirname, 'AccessControl.json');
		var ACC = await contract(file, AccAddr);
		var id32 = await ACC.methods.stringToBytes32(_ID).call();
		let result = await ACC.methods.AccessClientL(id32).call();
		let NoFR = result.NoFR,
		NoB = parseInt(result.NoB),
		ToUnB = result.ToUnB;
		let penalty = 0;
		let errorcode = 0,
		res = true;
		let misbehavior = "";
		var currentTime = parseInt(new Date().getTime() / 1000);
		if (ack == 3) {
			errorcode = 3;
			res = false;
			misbehavior = "Public key is outtime!";
			penalty = misbehaviorJudge(NoB);
			console.log('penalty: ' + penalty);
			ToUnB = currentTime + penalty * 60;
			NoB += 1;
		} else {
			if (!result.isValued) {
				console.log("Add new client!");
				await MC.methods.clientCon(_ID).send({
					from: R1Addr,
					gas: 40000000
				}).then((receipt) => {
					console.log('clientCon transactionHash: ' + receipt.transactionHash);
				});
				await ACC.methods.ACLInite(_DID, _ID, currentTime, errorcode, res).send({
					from: R1Addr,
					gas: 4000000
				}).then(async(receipt) => {
					currentTxHash = receipt.transactionHash;
					await ACC.getPastEvents('ReturnAccessResult', {
						fromBlock: 0,
						toBlock: 'latest'
					}, (error, results) => {
						for (result of results) {
							if (previousTxHash != result.transactionHash && currentTxHash == result.transactionHash) {
								console.log('ACLInite transactionHash: ' + result.transactionHash);
								console.log("Client " + result.returnValues._from + ", Time: " + result.returnValues._time + ", Errorcode: " + result.returnValues._err);
								console.log("Access Reported!");
								previousTxHash = result.transactionHash;
							}
						}
					});
				});
				return;
			}
			if (ToUnB >= currentTime) { //still blocked state
				errorcode = 1; //"Requests are blocked!"
				res = false;
				misbehavior = "Requests are blocked!"
			} else { //unblocked state
				if (ToUnB > 0) {
					ToUnB = 0;
					NoFR = 0;
				}
				let time = (await(ACC.methods.getAccessReport(_ID, result.Num - 1).call())).time;
				console.log('Now: ' + time);
				if (currentTime - time <= minInterval) {
					NoFR++;
					if (NoFR >= ThroFR) {
						misbehavior = "Too frequent access!";
						penalty = misbehaviorJudge(NoB);
						console.log('penalty: ' + penalty);
						errorcode = 2;
						ToUnB = currentTime + penalty * 60;
						NoB += 1;
					}
				} else {
					NoFR = 0;
				}
			}
			if (errorcode != 0)
				res = false;
			console.log("Access Reporting!");
			console.log(_ID, ToUnB, NoFR, currentTime, errorcode, res);
			let events = await ACC.methods.setACL(_ID, ToUnB, NoFR, currentTime, errorcode, res).send({
					from: R1Addr,
					gas: 3000000
				});
			currentTxHash = events.transactionHash;
			await ACC.getPastEvents('ReturnAccessResult', {
				fromBlock: 0,
				toBlock: 'latest'
			}, (error, results) => {
				for (result of results) {
					
					if (previousTxHash != result.transactionHash && currentTxHash == result.transactionHash) {
						console.log('transactionHash: ' + result.transactionHash);
						console.log("Client " + result.returnValues._from + ", Time: " + result.returnValues._time + ", Errorcode: " + result.returnValues._err);
						console.log("Access Reported!");
						if (errorcode == 1)
							console.log("Now: " + currentTime + ", ToUnB:" + ToUnB);
						previousTxHash = result.transactionHash;
					}
				}
			}); ;
		}
		if (0 == errorcode)
			misbehavior = "Access authorized!";
		console.log(misbehavior);
		if (ack == 2) {
			errorcode = 5;
			console.log("Public key is malicious");
		}
		if (penalty > 0) {
			console.log("Client misbehavior report!");
			await ACC.methods.misbehaviorRe(_ID, currentTime, misbehavior, penalty).send({
				from: R1Addr,
				gas: 4000000
			}).then((receipt) => {
				console.log('misbehavior transactionHash: ' + receipt.transactionHash);
			});
		}
		if (NoB >= ThroB) {
			console.log("Client REV report!");
			await MC.methods.clientRev(_ID).send({
				from: R1Addr,
				gas: 4000000
			}).then((receipt) => {
				console.log('clientRev transactionHash: ' + receipt.transactionHash);
			});
		}
		console.log("\n");
	}
}


const readline = require('readline');
const rl = readline.createInterface({
		input: process.stdin,
		output: process.stdout
	});
	
rl.setPrompt('Send access request?(clientID,DomainID)');
rl.prompt();

rl.on('line', async(answer) => {
	var c = answer.split(",");
	await ACC(c[0], c[1]);
	rl.prompt();
})

rl.on('close', function () {
	console.log('Have a great day!');
	process.exit(0);
});
