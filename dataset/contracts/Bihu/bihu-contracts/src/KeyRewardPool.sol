pragma solidity 0.4.18;

import "ds-math/math.sol";
import "ds-token/token.sol";

contract KeyRewardPool is DSMath, DSNote{

    DSToken public key;
    uint public rewardStartTime;

    uint constant public yearlyRewardPercentage = 10; // 10% of remaining tokens
    uint public totalRewardThisYear;
    uint public collectedTokens;
    address public withdrawer;
    address public owner;
    bool public paused;

    event TokensWithdrawn(address indexed _holder, uint _amount);
    event LogSetWithdrawer(address indexed _withdrawer);
    event LogSetOwner(address indexed _owner);

    modifier onlyWithdrawer {
        require(msg.sender == withdrawer);
        _;
    }
    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    modifier notPaused() {
        require(!paused);
        _;
    }

    function KeyRewardPool(uint _rewardStartTime, address _key, address _withdrawer) public{
        require(_rewardStartTime != 0 );
        require(_key != address(0) );
        require(_withdrawer != address(0) );
        require(_rewardStartTime > now - 364 days);

        rewardStartTime = _rewardStartTime;
        key = DSToken(_key);
        withdrawer = _withdrawer;
        owner = msg.sender;
        paused = false;
    }

    // @notice call this method to extract the tokens
    function collectToken() public notPaused onlyWithdrawer{
        uint _time = time();
        var _key = key;  // create a in memory variable for storage variable will save gas usage.

        require(_time > rewardStartTime);

        uint balance = _key.balanceOf(address(this));
        uint total = add(collectedTokens, balance);

        uint remainingTokens = total;

        uint yearCount = yearFor(_time);

        for(uint i = 0; i < yearCount; i++) {
            remainingTokens =  div( mul(remainingTokens, 100 - yearlyRewardPercentage), 100);
        }
        //
        totalRewardThisYear =  div( mul(remainingTokens, yearlyRewardPercentage), 100);

        // the reward will be increasing linearly in one year.
        uint canExtractThisYear = div( mul(totalRewardThisYear, (_time - rewardStartTime)  % 365 days), 365 days);

        uint canExtract = canExtractThisYear + total - remainingTokens;

        canExtract = sub(canExtract, collectedTokens);

        if(canExtract > balance) {
            canExtract = balance;
        }

        
        collectedTokens = add(collectedTokens, canExtract);

        assert(_key.transfer(withdrawer, canExtract)); // Fix potential re-entry bug.
        TokensWithdrawn(withdrawer, canExtract);
    }


    function yearFor(uint timestamp) public constant returns(uint) {
        return timestamp < rewardStartTime
            ? 0
            : sub(timestamp, rewardStartTime) / (365 days);
    }

    // overrideable for easy testing
    function time() public constant returns (uint) {
        return now;
    }

    function setWithdrawer(address _withdrawer) public onlyOwner {
        withdrawer = _withdrawer;
        LogSetWithdrawer(_withdrawer);
    }

    function setOwner(address _owner) public onlyOwner {
        owner = _owner;
        LogSetOwner(_owner);
    }


    function pauseCollectToken() public onlyOwner {
        paused = true;
    }

    function resumeCollectToken() public onlyOwner {
        paused = false;
    }

    // @notice This method can be used by the controller to extract mistakenly
    //  sent tokens to this contract.
    // @param dst The address that will be receiving the tokens
    // @param wad The amount of tokens to transfer
    // @param _token The address of the token contract that you want to recover
    function transferTokens(address dst, uint wad, address _token) public onlyWithdrawer {
        require( _token != address(key));
        if (wad > 0) {
            ERC20 token = ERC20(_token);
            token.transfer(dst, wad);
        }
    }

    
}
