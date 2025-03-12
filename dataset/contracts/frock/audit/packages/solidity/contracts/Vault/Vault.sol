// SPDX-License-Identifier: MIT
pragma solidity ^0.8.5;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol";
import "../DividenDistributor/IDividenDistributor.sol";

contract Vault is Context{

    struct Withdraw {
        uint256 withdrawAmount;
        uint256 withdrawTime;
    }

    bytes4 public constant DIVIDEN_DISTRIBUTOR = type(IDividenDistributor).interfaceId;

    // Fixed Parameters
    address public frockToken; // Address of Frock Token/Token that will be locked
    address public dividenDistributor;
    address public holder; // address of token's holder that lock the token
    uint256 public amountFrockTokenLocked; // amount token that locked
    uint256 public lockPeriode; // How long the token will be locked before will be able to withdraw
    uint256 public startLock; // start time of token's lock
    uint256 public endLock; // end time of token's lock
    uint256 public periodPerWithdraw; // Period of each withdrawal, ex : for a month only able to withdraw once
    uint256 public maxAmountPerWithdraw; // Amount fo token that able to withdraw per withdrawal's periode

    // Dynamic Parameter
    uint256 totalWithdraw;
    bool isLocked; // Lock State    
    mapping(uint256 => Withdraw) public withdrawalHistory; // Epoch withdrawal => time of withdrawal
    
    event Locked(
        address indexed holder, 
        uint256 amountFrockTokenLocked, 
        uint256 lockPeriode, 
        uint256 periodPerWithdraw, 
        uint256 amountPerWithdraw
    );
    event WithdrawToken(uint256 epoch, uint256 withdrawAmount);
    event ClaimDividen(uint256 rewardId, uint256 rewardAmount);

    constructor(address _frockToken, address _dividenDistributor) {
        frockToken = _frockToken;   
        dividenDistributor = _dividenDistributor;     
        isLocked = false;
    }

    function lockToken(
        uint256 amountFrockTokenLockedParam,
        uint256 lockPeriodeParam,    
        uint256 periodPerWithdrawParam,
        uint256 maxAmountPerWithdrawParam
    ) external {
        // Requirement
        require(!isLocked, "Vault: Already Locked");

        // Transfer Token
        require(
            IERC20(frockToken).transferFrom(_msgSender(), address(this), amountFrockTokenLockedParam),
            "Vault: Transfer Failed"
        );

        // Update State
        isLocked = true;
        holder = _msgSender();
        amountFrockTokenLocked = amountFrockTokenLockedParam;
        lockPeriode = lockPeriodeParam;
        startLock = block.timestamp;
        endLock = startLock + lockPeriode;
        periodPerWithdraw = periodPerWithdrawParam;
        maxAmountPerWithdraw = maxAmountPerWithdrawParam;        

        emit Locked(
            _msgSender(), 
            amountFrockTokenLockedParam, 
            lockPeriodeParam, 
            periodPerWithdrawParam, 
            maxAmountPerWithdrawParam
        );
    }

    function currentEpoch() public view returns(uint256) {
        require(block.timestamp > endLock, "Vault: Cannot Calculate Epoch");
        return (block.timestamp - (endLock))/periodPerWithdraw;
    }

    function withdraw(uint256 withdrawAmount) external {
        require(holder == _msgSender(), "Vault: Not the Holder");        
        require(withdrawAmount <= maxAmountPerWithdraw, "Vault: withdrawal exceed limit");
        require((amountFrockTokenLocked - totalWithdraw) >= withdrawAmount,"Vault: withdrawal exceed stocks");

        uint256 epoch = currentEpoch();
        require(withdrawalHistory[epoch].withdrawTime == 0, "Vault: Already Withdraw for This Period");

        // Update Value
        withdrawalHistory[epoch] = Withdraw(withdrawAmount, block.timestamp);
        totalWithdraw += withdrawAmount;

        // Transfer Token
        require(
            IERC20(frockToken).transfer(holder, withdrawAmount),
            "Vault: Transfer Failed"
        );

        emit WithdrawToken(epoch, withdrawAmount);
    }

    function claimDividen(uint256 rewardId) external returns(uint256 rewardAmount ) {
        if(IERC165Upgradeable(dividenDistributor).supportsInterface(DIVIDEN_DISTRIBUTOR)) {
            IDividenDistributor(dividenDistributor).claimReward(rewardId);
            rewardAmount = address(this).balance;
            _safeTransferETH(holder, rewardAmount);
            emit ClaimDividen(rewardId, rewardAmount);
            return rewardAmount;
        }
        revert("Vault: Address not support claimReward");
    }

    function _safeTransferETH(address to, uint value) internal {
        (bool success,) = to.call{value:value}(new bytes(0));
        require(success, 'Vault: ETH_TRANSFER_FAILED');
    }

    // Function to receive Ether. msg.data must be empty
    receive() external payable {}

    // Fallback function is called when msg.data is not empty
    fallback() external payable {}
    
}