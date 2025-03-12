// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./lib/SafeDecimalMath.sol";
import "./interface/IAddressResolver.sol";
import "./interface/IFeePool.sol";


contract FeePool is ReentrancyGuard, IFeePool{
    using SafeMath for uint;
    using SafeDecimalMath for uint;

    bytes32 public constant BOR = "BOR";
    bytes32 public  OTOKEN;
    bytes32 public PTOKEN;

    bytes32 public tunnelKey;
    IAddressResolver public addrReso;

    uint public borFeePerTokenStored;
    uint public oTokenFeePerTokenStored;

    mapping(address => uint) public userBORFee;
    mapping(address => uint) public userBORFeePaid;
    mapping(address => uint) public userOTokenFee;
    mapping(address => uint) public userOTokenFeePaid;



    mapping(address => uint) private _balances;

    constructor(IAddressResolver _addrReso, bytes32 _tunnelKey, bytes32 _btokenKey, bytes32 _ptokenKey) public {
        addrReso = _addrReso;
        tunnelKey = _tunnelKey;
        OTOKEN = _btokenKey;
        PTOKEN = _ptokenKey;
    }

    function bor() internal view returns (IERC20) {
        return IERC20(addrReso.requireAndKey2Address(BOR, "BOR contract is address(0) in FeePool"));
    }

    function otoken() internal view returns(IERC20) {
        return IERC20(addrReso.requireAndKey2Address(OTOKEN, "oToken contract is address(0) in FeePool"));
    }

    function ptoken() internal view returns(IERC20) {
        return IERC20(addrReso.requireAndKey2Address(PTOKEN, "oToken contract is address(0) in FeePool"));
    }

    function totalSupply() external view returns (uint256) {
        return ptoken().totalSupply();
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function borFeePerToken() public view returns(uint) {
        return borFeePerTokenStored;
    }

    function oTokenFeePerToken() public view returns(uint) {
        return oTokenFeePerTokenStored;
    }

    function earned(address account) public view override returns(uint, uint) {
        uint borFee = _balances[account].multiplyDecimal(borFeePerTokenStored.sub(userBORFeePaid[account])).add(userBORFee[account]);
        uint btokenFee = _balances[account].multiplyDecimal(oTokenFeePerTokenStored.sub(userOTokenFeePaid[account])).add(userOTokenFee[account]);
        return (borFee, btokenFee);
    }

    function getTotalFee() public view returns(uint, uint) {
        return (bor().balanceOf(address(this)), otoken().balanceOf(address(this)));
    }

    function notifyBORFeeAmount(uint amount) external override onlyTunnel {
        borFeePerTokenStored = borFeePerTokenStored.add(amount.divideDecimal(ptoken().totalSupply()));
    }

    function notifyBTokenFeeAmount(uint amount) external override onlyTunnel {

        oTokenFeePerTokenStored = oTokenFeePerTokenStored.add(amount.divideDecimal(ptoken().totalSupply()));
    }

    function notifyPTokenAmount(address account, uint amount) external override onlyTunnel {
        // first update account rewards
        (uint earnedBOR, uint earnedOToken) = earned(account);
        userBORFee[account] = earnedBOR; 
        userOTokenFee[account] = earnedOToken; 

        userBORFeePaid[account] = borFeePerTokenStored;
        userOTokenFeePaid[account] = oTokenFeePerTokenStored;

        _balances[account] = _balances[account].add(amount);
    }

    function withdraw(address account, uint amount) external override onlyTunnel{
        _claimFee(account);
        _balances[account] = _balances[account].sub(amount);
    }

    function claimFee() external {
        _claimFee(msg.sender);
    }

    function _claimFee(address account) internal {
        (uint earnedBOR, uint earnedOToken) = earned(account);
        userBORFee[account] = 0;
        userBORFeePaid[account] = borFeePerTokenStored;

        userOTokenFee[account] = 0;
        userOTokenFeePaid[account] = oTokenFeePerTokenStored;
        
        bor().transfer(account, earnedBOR);
        otoken().transfer(account, earnedOToken);

    }

    // modifier
    modifier onlyTunnel {
        require(
            msg.sender == addrReso.key2address(tunnelKey),
            "caller is not tunnel"
        );
        _;
    }


}