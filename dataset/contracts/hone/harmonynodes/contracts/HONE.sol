// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IHarmony_NodeManage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";
contract HONE is ERC20, Ownable {
  
  uint256 private initalSupply = 600 * 1000 * 10 ** 18;
  uint256 private denominator = 100;

  uint256 public transferFee;
  uint256 public saleFee;
  uint256 public checkHasNode;
  address private _owner;
  address private honeNode;
  address private feeCollectWallet;
  address private usdcAddress;

  IHarmony_NodeMange HONE_NODE;
  IUniswapV2Router02 private uniswapV2Router02;
  IUniswapV2Factory private uniswapV2Factory;
  IUniswapV2Pair private uniswapV2Pair;

  mapping (address => bool) private blacklist;
  /**
  addr
    0: usdt address
    1: defira swap router
    2: feeCollectWallet
  value
    0: sale fee
    1: transfer fee
   */
  constructor(address[3] memory _addr, uint256[2] memory _value) ERC20('HONE token', 'HONE') {
      uniswapV2Router02 = IUniswapV2Router02(_addr[1]);
      uniswapV2Factory = IUniswapV2Factory(uniswapV2Router02.factory());
      usdcAddress = _addr[0];
      uniswapV2Pair = IUniswapV2Pair(uniswapV2Factory.createPair(address(this), usdcAddress));
      setSaleFee(_value[0]);
      setTransferFee(_value[1]);
      setFeeCollectWallet(_addr[2]);

      _mint(msg.sender, initalSupply);
      _owner = msg.sender;
  }

  function setSaleFee(uint _saleFee) public onlyOwner{
    saleFee = _saleFee;
  }

  function setTransferFee(uint _transferFee) public onlyOwner{
    transferFee = _transferFee;
  }

  function setFeeCollectWallet(address _feeCollectWallet) public onlyOwner{
    feeCollectWallet = _feeCollectWallet;
  }

  function setNodeManagementContract(address _honeNode) onlyOwner public{
    honeNode = _honeNode;
    HONE_NODE = IHarmony_NodeMange(honeNode);
  }
  /**
    * @dev Calculates the tax, transfer it to the feeCollectWallet.
    */
  function handleTax(address from, address to, uint256 amount) private returns (uint256) {
      address[] memory sellPath = new address[](2);
      sellPath[0] = address(this);
      sellPath[1] = usdcAddress;
      
      uint256 tax;
      uint256 baseUnit = amount / denominator;

      if (to == address(uniswapV2Pair)) {//sell
        if (checkHasNode == 1)
        {
          uint countNode = HONE_NODE.getNodeCount(from);
          require(countNode >= 1, "you haven't any Node.");
        }
      }
      if(from == address(uniswapV2Pair)) {   // buy fee : 0
          
      } else if(to == address(uniswapV2Pair)) {  // sell fee logic
        tax = baseUnit * saleFee;
      } else { // transfer fee
        tax = baseUnit * transferFee;
      }

      if(tax > 0) {
          _transfer(from, feeCollectWallet, tax);   
      }

      amount -= tax;
      
      return amount;
  }

  function _transfer(
    address sender,
    address recipient,
    uint256 amount
  ) internal override virtual {

    require(!isBlacklisted(msg.sender), "HONE TOKEN: sender blacklisted");
    require(!isBlacklisted(recipient), "HONE TOKEN: recipient blacklisted");
    amount = handleTax(sender, recipient, amount);   
    
    super._transfer(sender, recipient, amount);
  }
  /**
  * @dev Blacklists the specified account (Disables transfers to and from the account).
  */
  function enableBlacklist(address account) public onlyOwner{
    require(!blacklist[account], "HONE TOKEN: Account is already blacklisted");
    blacklist[account] = true;
  }
  
  /**
  * @dev Remove the specified account from the blacklist.
  */
  function disableBlacklist(address account) public onlyOwner {
    require(blacklist[account], "HONE TOKEN: Account is not blacklisted");
    blacklist[account] = false;
  }
  /**
  * @dev Returns true if the account is blacklisted, and false otherwise.
  */
  function isBlacklisted(address account) public view returns (bool) {
      return blacklist[account];
  }
  /**
  * @dev Blacklists the specified account (Disables transfers to and from the account).
  */
  function setCheckHasNode(uint256 _checkHasNode) public onlyOwner{
    checkHasNode = _checkHasNode;
  }
  function mint(uint256 _amount) public {
    require(msg.sender == honeNode || msg.sender == _owner, 'Can only be used by honeNode or owner.');
    _mint(msg.sender, _amount);
  }

  function burn(uint256 _amount) public {
    require(msg.sender == honeNode || msg.sender == _owner, 'Can only be used by honeNode or owner.');
    _burn(msg.sender, _amount);
  }

  receive() external payable {}
}