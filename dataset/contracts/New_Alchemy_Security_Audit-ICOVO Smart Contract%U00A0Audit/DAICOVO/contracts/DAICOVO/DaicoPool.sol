pragma solidity ^0.4.19;

import '../ownership/Ownable.sol';
import '../math/SafeMath.sol';
import '../token/ERC20/ERC20Interface.sol';
import './Voting.sol';


contract DaicoPool is Ownable {
    using SafeMath for uint256;

    address public tokenSaleAddr;
    address public votingAddr;
    address public votingTokenAddr;
    uint256 public tap;
    uint256 public initialTap;
    uint256 public initialRelease;
    uint256 public releasedBalance;
    uint256 public withdrawnBalance;
    uint256 public lastUpdatedTime;
    uint256 public fundRaised;
    mapping (address => uint256) deposits;
    uint256 public closingRelease = 30 days;

    /* The unit of this variable is [10^-9 wei / token], intending to minimize rouding errors */
    uint256 public refundRateNano = 0;
  
    enum Status {
        Initializing,
        ProjectInProgress,
        Destructed
    }
  
    Status public status;

    event TapHistory(uint256 new_tap);
    event WithdrawalHistory(string token, uint256 amount);
    event Refund(address receiver, uint256 amount);

    modifier onlyTokenSaleContract {
        require(msg.sender == tokenSaleAddr);
        _;
    }

    modifier onlyVoting {
        require(msg.sender == votingAddr);
        _;
    }

    modifier poolInitializing {
        require(status == Status.Initializing);
        _;
    }

    modifier poolDestructed {
        require(status == Status.Destructed);
        _;
    }

    function DaicoPool(address _votingTokenAddr, uint256 tap_amount, uint256 _initialRelease) public {
        require(_votingTokenAddr != 0x0);

        initialTap = tap_amount;
        votingTokenAddr = _votingTokenAddr;
        status = Status.Initializing;
        initialRelease = _initialRelease;
 
        votingAddr = new Voting(ERC20Interface(_votingTokenAddr), address(this));
    }

    function () external payable {}

    function setTokenSaleContract(address _tokenSaleAddr) external {
        /* Can be set only once */
        require(tokenSaleAddr == address(0x0));
        require(_tokenSaleAddr != address(0x0));
        tokenSaleAddr = _tokenSaleAddr;
    }

    function startProject() external onlyTokenSaleContract {
        require(status == Status.Initializing);
        status = Status.ProjectInProgress;
        lastUpdatedTime = block.timestamp;
        releasedBalance = initialRelease;
        updateTap(initialTap);
        fundRaised = this.balance;
    }

    function withdraw(uint256 amount) public onlyOwner {
        require(amount > 0);
        updateReleasedBalance();
        uint256 available_balance = getAvailableBalance();
        if (amount > available_balance) {
            amount = available_balance;
        }

        withdrawnBalance = withdrawnBalance.add(amount);
        owner.transfer(amount);

        WithdrawalHistory("ETH", amount);
    }

    function raiseTap(uint256 tapMultiplierRate) external onlyVoting {
        updateReleasedBalance();
        updateTap(tap.mul(tapMultiplierRate.div(100)));
    }

    function selfDestruction() external onlyVoting {
        status = Status.Destructed;
        updateReleasedBalance();
        releasedBalance.add(closingRelease.mul(tap));
        updateTap(0);

        uint256 _totalSupply = ERC20Interface(votingTokenAddr).totalSupply(); 
        refundRateNano = address(this).balance.sub(getAvailableBalance()).mul(10**9).div(_totalSupply);
    }

    function refund(uint256 tokenAmount) external poolDestructed {
        require(ERC20Interface(votingTokenAddr).transferFrom(msg.sender, this, tokenAmount));

        uint256 refundingEther = tokenAmount.mul(refundRateNano).div(10**9);
        Refund(msg.sender, tokenAmount);
        msg.sender.transfer(refundingEther);
    }

    function getReleasedBalance() public constant returns(uint256) {
        uint256 time_elapsed = block.timestamp.sub(lastUpdatedTime);
        return releasedBalance.add(time_elapsed.mul(tap));
    }
 
    function getAvailableBalance() public constant returns(uint256) {
        uint256 available_balance = getReleasedBalance() - withdrawnBalance;

        if (available_balance > address(this).balance) {
            available_balance = address(this).balance;
        }

        return available_balance;
    }

    function updateReleasedBalance() internal {
        releasedBalance = getReleasedBalance();
        lastUpdatedTime = block.timestamp;
    }

    function updateTap(uint256 new_tap) private {
        tap = new_tap;
        TapHistory(new_tap);
    }
}
