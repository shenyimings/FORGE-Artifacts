pragma solidity 0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";
import "./IDOPool.sol";
import "./interfaces/IidoMaster.sol";

contract IDOCreator is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for ERC20Burnable;
    using SafeERC20 for ERC20;

    IidoMaster  public  idoMaster;
    ITierSystem  public  tierSystem;
    
    constructor(
        IidoMaster _idoMaster,
        ITierSystem _tierSystem
    ) public {
        idoMaster = _idoMaster;
        tierSystem = _tierSystem;
    }

    function createIDO(
        uint256 _tokenPrice,
        ERC20 _rewardToken,
        uint256 _startTimestamp,
        uint256 _finishTimestamp,
        uint256 _startClaimTimestamp,
        uint256 _minEthPayment,
        uint256 _maxEthPayment,
        uint256 _maxDistributedTokenAmount,
        bool _hasWhitelisting,
        bool _enableTierSystem
    ) external returns (address){
        
        if(idoMaster.feeAmount() > 0){
            uint256 burnAmount = idoMaster.feeAmount().mul(idoMaster.burnPercent()).div(idoMaster.divider());
            idoMaster.feeToken().safeTransferFrom(
                msg.sender,
                idoMaster.feeWallet(),
                idoMaster.feeAmount().sub(burnAmount)
            );
           
            if(burnAmount > 0) {
                idoMaster.feeToken().safeTransferFrom(msg.sender, address(this), burnAmount);
                idoMaster.feeToken().burn(burnAmount);
            }
        }

        IDOPool idoPool =
            new IDOPool(
                idoMaster,
                idoMaster.feeFundsPercent(),
                _tokenPrice,
                _rewardToken,
                _startTimestamp,
                _finishTimestamp,
                _startClaimTimestamp,
                _minEthPayment,
                _maxEthPayment,
                _maxDistributedTokenAmount,
                _hasWhitelisting,
                _enableTierSystem,
                tierSystem
            );

        idoPool.transferOwnership(msg.sender);

        _rewardToken.safeTransferFrom(
            msg.sender,
            address(idoPool),
            _maxDistributedTokenAmount
        );

        require(_rewardToken.balanceOf(address(idoPool)) == _maxDistributedTokenAmount,  "Unsupported token");

        idoMaster.registrateIDO(address(idoPool),   
                                _tokenPrice,
                                address(0),
                                address(_rewardToken),
                                _startTimestamp,
                                _finishTimestamp,
                                _startClaimTimestamp,
                                _minEthPayment,
                                _maxEthPayment,
                                _maxDistributedTokenAmount);

         return address(idoPool);
    }

    function isContract(address _addr) private view returns (bool) {
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }

    function setTierSystem(ITierSystem _tierSystem) external onlyOwner {
        tierSystem = _tierSystem;
    }

    // ============ Version Control ============
    function version() external pure returns (uint256) {
        return 101; // 1.0.1
    }
}