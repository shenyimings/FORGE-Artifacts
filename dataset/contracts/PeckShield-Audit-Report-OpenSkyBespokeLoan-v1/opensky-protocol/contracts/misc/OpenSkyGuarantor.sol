// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "../interfaces/IOpenSkySettings.sol";
import "../interfaces/IOpenSkyPool.sol";
import "../interfaces/IOpenSkyLoan.sol";
import "../interfaces/IACLManager.sol";
import "../interfaces/IOpenSkyIncentivesController.sol";
import "../dependencies/aave/ILendingPool.sol";
import "../libraries/types/DataTypes.sol";
import "../libraries/math/WadRayMath.sol";
import "./OpenSkyIncentivesProxy.sol";

contract OpenSkyGuarantor is ERC721, ERC721Holder, OpenSkyIncentivesProxy {
    using SafeERC20 for IERC20;
    using WadRayMath for uint128;

    IOpenSkySettings public immutable settingsContract;
    IOpenSkyPool public immutable poolContract;
    IOpenSkyLoan public immutable loanContract;
    ILendingPool public immutable aaveContract;
    IERC20 public immutable underlyingAssetContract;

    mapping(uint256 => uint256) public guarantyAmounts;

    event Guarantee(address indexed sender, uint256 indexed loanId, uint256 amount);
    event ClaimNFT(address indexed sender, uint256 indexed loanId, uint256 amount, address nftAddress, uint256 tokenId);
    event ClaimUnderlyingAsset(address indexed sender, uint256 indexed loanId, uint256 amount);

    modifier onlyGovernance() {
        IACLManager ACLManager = IACLManager(settingsContract.ACLManagerAddress());
        require(ACLManager.isGovernance(_msgSender()), "ONLY_GOVERNANCE");
        _;
    }

    constructor(
        IOpenSkySettings settingsContract_,
        ILendingPool aaveContract_,
        IERC20 underlyingAssetContract_
    ) ERC721 ("OpenSky Guaranties", "GURATANTY") {
        settingsContract = settingsContract_;
        loanContract = IOpenSkyLoan(settingsContract_.loanAddress());
        poolContract = IOpenSkyPool(settingsContract_.poolAddress());
        aaveContract = aaveContract_;
        underlyingAssetContract = underlyingAssetContract_;
    }

    function getGuarantyAmount(uint256 loanId) public view returns (uint256) {
        return guarantyAmounts[loanId];
    }

    function guarantee(uint256 loanId) external {
        // mint NFT
        _mint(_msgSender(), loanId);

        uint256 amount = getGuaranteeAmount(loanId);
        guarantyAmounts[loanId] = amount;

        underlyingAssetContract.safeTransferFrom(_msgSender(), address(userProxies[_getUserProxy(_msgSender())]), amount);

        emit Guarantee(_msgSender(), loanId, amount);
    }

    function getGuaranteeAmount(uint256 loanId) public view returns (uint256) {
        DataTypes.LoanData memory loan = loanContract.getLoanData(loanId);
        require(loan.liquidatableTime > block.timestamp, 'LOAN_DEFAULT');
        uint256 borrowBalance = loan.amount + loan.interestPerSecond.rayMul(loan.liquidatableTime - loan.borrowBegin);
        return borrowBalance + (borrowBalance * 100) / 10000;
    }

    function _getFlashloanAmount(uint256 amount) internal view returns (uint256) {
        return amount + amount * aaveContract.FLASHLOAN_PREMIUM_TOTAL() / 10000;
    }

    function claimUnderlyingAsset(uint256 loanId) external {
        require(ownerOf(loanId) == _msgSender(), "ONLY_OWNER");

        try loanContract.getLoanData(loanId) returns (DataTypes.LoanData memory) {
            revert("LOAN_HAS_NOT_BEEN_REPAID");
        } catch (bytes memory) {
            bytes memory data = abi.encodeWithSignature("transfer(address,uint256)", _msgSender(), guarantyAmounts[loanId]);
            _callUserProxy(ownerOf(loanId), address(underlyingAssetContract), data);

            _burn(loanId);

            emit ClaimUnderlyingAsset(_msgSender(), loanId, guarantyAmounts[loanId]);
        }
    }

    function claimNFT(uint256 loanId) public {
        require(ownerOf(loanId) == _msgSender(), "ONLY_OWNER");

        DataTypes.LoanData memory loan = loanContract.getLoanData(loanId);

        poolContract.startLiquidation(loanId);

        if (poolContract.getAvailableLiquidity(loan.reserveId) >= guarantyAmounts[loanId]) {
            bytes memory data = abi.encodeWithSignature("withdraw(uint256,uint256,address)", loan.reserveId, guarantyAmounts[loanId], address(this));
            _callUserProxy(ownerOf(loanId), address(poolContract), data);

            _endLiquidation(loanId, false);
        } else {
            // OpenSky pool liquidity is insufficient
            // liquidate via aave.flashLoan()
            address[] memory assets = new address[](1);
            assets[0] = poolContract.getReserveData(loan.reserveId).underlyingAsset;
            uint256[] memory amounts = new uint256[](1);
            amounts[0] = loanContract.getBorrowBalance(loanId);
            uint256[] memory modes = new uint256[](1);
            modes[0] = 0;
            aaveContract.flashLoan(address(this), assets, amounts, modes, address(this), uint256ToBytes(loanId), 0);
        }

        _burn(loanId);

        emit ClaimNFT(_msgSender(), loanId, guarantyAmounts[loanId], loan.nftAddress, loan.tokenId);
    }

    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external returns (bool) {
        require(address(aaveContract) == _msgSender(), "CALLER_MUST_BE_AAVE");
        require(address(this) == initiator, "INITIATOR_MUST_BE_GUARANTOR");

        uint256 loanId = bytesToUint256(params);
        _endLiquidation(loanId, true);

        IERC20(assets[0]).safeApprove(address(aaveContract), amounts[0] + premiums[0]);

        return true;
    }

    function _endLiquidation(uint256 loanId, bool usedFlashloan) internal {
        DataTypes.LoanData memory loan = loanContract.getLoanData(loanId);

        uint256 borrowBalance = loanContract.getBorrowBalance(loanId);
        IERC20 underlyingAsset = IERC20(poolContract.getReserveData(loan.reserveId).underlyingAsset);
        underlyingAsset.safeApprove(address(poolContract), borrowBalance);
        poolContract.endLiquidation(loanId, borrowBalance);

        if (usedFlashloan) {
            // poolContract.withdraw(loan.reserveId, guarantyAmounts[loanId], address(this));
            bytes memory data = abi.encodeWithSignature("withdraw(uint256,uint256,address)", loan.reserveId, guarantyAmounts[loanId], address(this));
            _callUserProxy(ownerOf(loanId), address(poolContract), data);
        }

        // distribute extra token
        uint256 extraAmount = guarantyAmounts[loanId] - (usedFlashloan ? _getFlashloanAmount(borrowBalance) : borrowBalance);
        underlyingAsset.safeTransfer(settingsContract.treasuryAddress(), extraAmount);

        IERC721(loan.nftAddress).safeTransferFrom(address(this), ownerOf(loanId), loan.tokenId);
    }

    function uint256ToBytes(uint256 _value) internal pure returns (bytes memory bs) {
        require(
            _value <= 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            "Value exceeds the range"
        );
        assembly {
            // Get a location of some free memory and store it in result as
            // Solidity does for memory variables.
            bs := mload(0x40)
            // Put 0x20 at the first word, the length of bytes for uint256 value
            mstore(bs, 0x20)
            //In the next word, put value in bytes format to the next 32 bytes
            mstore(add(bs, 0x20), _value)
            // Update the free-memory pointer by padding our last write location to 32 bytes
            mstore(0x40, add(bs, 0x40))
        }
    }

    function bytesToUint256(bytes memory _bs) internal pure returns (uint256 value) {
        require(_bs.length == 32, "bytes length is not 32.");
        assembly {
            // load 32 bytes from memory starting from position _bs + 32
            value := mload(add(_bs, 0x20))
        }
        require(value <= 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, "Value exceeds the range");
    }
}
