/**
 *Submitted for verification at Etherscan.io on 2020-05-13
*/

pragma solidity >=0.6.0;
import "./XBT.sol";

interface Minereum {
  function Payment (  ) payable external;
}

contract XBTLuckyDraw
{
	address public XBTGameFund;
	uint public stakeHoldersfee = 50;
	uint public percentWin = 80;
	uint public xbtfee = 0;
	uint public ethfee = 15000000000000000;
	uint public totalSentToStakeHolders = 0;
	uint public totalPaidOut = 0;
	uint public ticketsSold = 0;
	uint public ticketsPlayed = 0;
	address public owner = 0x0000000000000000000000000000000000000000;
	uint public maxNumber = 10001;
	uint public systemNumber = 3223;

	uint public blockInterval = 3;
	uint public maxBlock = 60;

	//winners from past contracts
	uint public winnersCount = 0;
	uint public winnersEthCount = 0;

	address[] public winners;
	uint[] public winnersTickets;
	uint[] public winnersETH;
	uint[] public winnersTimestamp;

	mapping (address => uint256) public playerBlock;
	mapping (address => uint256) public playerTickets;

	event Numbers(address indexed from, uint[] n, string m);

	constructor() public
	{
    xbt = new XBT();
		XBTGameFund = 0x426CA1eA2406c07d75Db9585F22781c096e3d0E0; // Some address with XBT fund for game
		owner = msg.sender;
		//data from old contract
		ticketsPlayed = 0;
		ticketsSold = 0;
	}

	receive() external payable { }

	function LuckyDraw() public
    {
        require(msg.sender == tx.origin);

		if (block.number >= playerBlock[msg.sender] + 256)
		{
			uint[] memory empty = new uint[](0);
			emit Numbers(address(this), empty, "Your tickets expired or are invalid. Try Again.");
			playerBlock[msg.sender] = 0;
			playerTickets[msg.sender] = 0;
		}
		else if (block.number > playerBlock[msg.sender] + blockInterval)
		{
			bool win = false;

			uint[] memory numbers = new uint[](playerTickets[msg.sender]);

			uint i = 0;
			while (i < playerTickets[msg.sender])
			{
				numbers[i] = uint256(uint256(keccak256(abi.encodePacked(blockhash(playerBlock[msg.sender] + 2), i)))%maxNumber);
				if (numbers[i] == systemNumber)
					win = true;
				i++;
			}

			ticketsPlayed += playerTickets[msg.sender];


			if (win)
			{
				address payable add = payable(msg.sender);
				uint contractBalance = address(this).balance;
				uint winAmount = contractBalance * percentWin / 100;
				uint totalToPay = winAmount;
				if (!add.send(totalToPay)) revert('Error While Executing Payment.');
				totalPaidOut += totalToPay;

				winnersCount++;
				winnersEthCount += totalToPay;
				emit Numbers(address(this), numbers, "YOU WON!");

				winners.push(msg.sender);
				winnersTickets.push(playerTickets[msg.sender]);
				winnersETH.push(totalToPay);
				winnersTimestamp.push(block.timestamp);
			}
			else
			{
				emit Numbers(address(this), numbers, "Your numbers don't match the System Number! Try Again.");
			}

			playerBlock[msg.sender] = 0;
			playerTickets[msg.sender] = 0;
		}
		else
		{
			revert('Players must wait 3 blocks');
		}
    }

	function BuyTickets(address _sender, uint256[] memory _max) public payable returns (uint256)
    {
		require(msg.sender == address(mne));
		require(_sender == tx.origin);

		if (_max[0] == 0) revert('value is 0');

		if (playerBlock[_sender] == 0)
		{
			uint valueStakeHolder = msg.value * stakeHoldersfee / 100;
			ticketsSold += _max[0];
			uint totalEthfee = ethfee * _max[0];
			uint totalXBTFee = xbtfee * _max[0];

			playerBlock[_sender] = block.number;
			playerTickets[_sender] = _max[0];

			if (msg.value < totalEthfee) revert('Not enough ETH.');
			mne.Payment.value(valueStakeHolder)();
			totalSentToStakeHolders += valueStakeHolder;
			return totalXBTFee;
		}
		else
		{
			revert('You must play the tickets first');
		}
    }

	function transferFundsOut() public
	{
		if (msg.sender == owner)
		{
			address payable add = payable(msg.sender);
			uint contractBalance = address(this).balance;
			if (!add.send(contractBalance)) revert('Error While Executing Payment.');
		}
		else
		{
			revert();
		}
	}

	function updateFees(uint _stakeHoldersfee, uint _xbtfee, uint _ethfee, uint _blockInterval) public
	{
		if (msg.sender == owner)
		{
			stakeHoldersfee = _stakeHoldersfee;
			xbtfee = _xbtfee;
			ethfee = _ethfee;
			blockInterval = _blockInterval;
		}
		else
		{
			revert();
		}
	}

	function updateSystemNumber(uint _systemNumber) public
	{
		if (msg.sender == owner)
		{
			systemNumber = _systemNumber;
		}
		else
		{
			revert();
		}
	}

	function updateMaxNumber(uint _maxNumber) public
	{
		if (msg.sender == owner)
		{
			maxNumber = _maxNumber;
		}
		else
		{
			revert();
		}
	}

	function updatePercentWin(uint _percentWin) public
	{
		if (msg.sender == owner)
		{
			percentWin = _percentWin;
		}
		else
		{
			revert();
		}
	}

	function updateMNEContract(address _mneAddress) public
	{
		if (msg.sender == owner)
		{
			mne = Minereum(_mneAddress);
		}
		else
		{
			revert();
		}
	}

	function WinnersLength() public view returns (uint256) { return winners.length; }
	function GetPlayerBlock(address _address) public view returns (uint256) { return playerBlock[_address]; }
	function GetPlayerTickets(address _address) public view returns (uint256) { return playerTickets[_address]; }
}