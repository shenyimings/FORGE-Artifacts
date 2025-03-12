pragma solidity ^0.8.13;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Faucet is Ownable {
    using SafeERC20 for IERC20;

    //state variable to keep track of owner and amount of ETHER to dispense
    uint public amountETHAllowed;
    uint public daysETHTimeLock;

    uint public amountTokenAllowed;
    uint public daysTokenTimeLock;

    //mapping to keep track of requested rokens
    //Address and blocktime + timeLock day is saved in TimeLock
    mapping(address => uint) public lockTimeETH;
    mapping(address => uint) public lockTimeToken;

    IERC20 public tokenFaucet;

    //constructor to set the owner
    constructor(uint _amountETHAllowed, uint _daysETHTimeLock, uint _amountTokenAllowed, uint _daysTokenTimeLock, address _tokenFaucet){
        amountETHAllowed = _amountETHAllowed;
        daysETHTimeLock = _daysETHTimeLock;
        amountTokenAllowed = _amountTokenAllowed;
        daysTokenTimeLock = _daysTokenTimeLock;
        tokenFaucet = IERC20(_tokenFaucet);

    }

    function setTokenFaucet(address _tokenFaucet) public onlyOwner {
        tokenFaucet = IERC20(_tokenFaucet);
    }

    function setAmountETHAllowed(uint newAmountETHAllowed) public onlyOwner {
        amountETHAllowed = newAmountETHAllowed;
    }

    function setETHTimeLock(uint newDaysETHTimeLock) public onlyOwner {
        daysETHTimeLock = newDaysETHTimeLock;
    }

    function setAmountTokenAllowed(uint newAmountTokenAllowed) public onlyOwner {
        amountTokenAllowed = newAmountTokenAllowed;
    }

    function setTokenTimeLock(uint newDaysTokenTimeLock) public onlyOwner {
        daysTokenTimeLock = newDaysTokenTimeLock;
    }


    //function to donate ETH to the faucet contract
    function donateETHToFaucet() public payable {
    }


    //function to send ETH from faucet to an address
    function requestETH(address payable _requestor) public payable {

        //perform a few checks to make sure function can execute
        require(block.timestamp > lockTimeETH[msg.sender], "Faucet: Lock time has not expired. Please try again later");
        require(address(this).balance > amountETHAllowed, "Faucet: Not enough funds in the faucet. Please donate");

        //if the balance of this contract is greater then the requested amount send funds
        _requestor.transfer(amountETHAllowed);

        //updates locktime 1 day from now
        lockTimeETH[msg.sender] = block.timestamp + daysETHTimeLock;
    }

    //function to send ETH from faucet to an address
    function requestToken(address payable _requestor) public {

        //perform a few checks to make sure function can execute
        require(block.timestamp > lockTimeToken[msg.sender], "Faucet: Lock time has not expired. Please try again later");
        require(tokenFaucet.balanceOf(address(this)) > amountTokenAllowed, "Faucet: Not enough funds in the faucet. Please donate");

        //if the balance of this contract is greater then the requested amount send funds
        tokenFaucet.safeTransfer(_requestor, amountTokenAllowed);

        //updates locktime 1 day from now
        lockTimeToken[msg.sender] = block.timestamp + daysTokenTimeLock;
    }
}
