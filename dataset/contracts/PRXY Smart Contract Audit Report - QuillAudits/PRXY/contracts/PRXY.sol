// SPDX-License-Identifier: NO LICENSE
pragma solidity 0.7.6;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract ProxyCoin is ERC20Burnable, Ownable {
  using SafeMath for uint256;
  uint256 public perBlockSupply = 2391000 * 1e18;
  uint256 public lastMintBlock;
  uint256 public mintDuration = 210000;
  address public treasuryWallet;
  uint256 public mintCycle;
  uint256 public mintCycleCap = 20;

  bool public startBlockSet;
 
  event MintDurationChanged(uint256 oldValue, uint256 newValue);
  event MintCycleCapChanged(uint256 oldValue, uint256 newValue);

  constructor (address _treasuryWallet, uint256 _lastMintBlock) ERC20("Proxy", "PRXY") {
    _setupDecimals(18);
    lastMintBlock = _lastMintBlock;
    treasuryWallet = _treasuryWallet;
    _mint(treasuryWallet, perBlockSupply);
    mintCycle++;
  }
  
  function setStartBlock(uint256 _lastMintBlock) external onlyOwner {
    require(!startBlockSet, "start block already set");
    lastMintBlock = _lastMintBlock;
    startBlockSet = true;
  }

  function startMinting() external onlyOwner {
    require(!mintingFinished(), "Err: Minting Finished");
    require(getMintingStatus(), "Err: Minting not allowed");
    lastMintBlock = block.number;
    perBlockSupply = (perBlockSupply * 9).div(10);
    _mint(treasuryWallet, perBlockSupply);
  }

  function mint(address addr, uint256 amount) public virtual onlyOwner {
    _mint(addr, amount);
  }

  function changeMintCycleCap(uint256 _mintCycleCap) external virtual onlyOwner {
    emit MintCycleCapChanged(mintCycleCap, _mintCycleCap);
    mintCycleCap = _mintCycleCap;
  }

  function changeMintDuration(uint256 _mintDuration) external virtual onlyOwner {
    emit MintDurationChanged(mintDuration, _mintDuration);
    mintDuration = _mintDuration;
  }
  
  function getBlockDifference() public view returns(uint256) {
    return (block.number.sub(lastMintBlock));
  }

  function getMintingStatus() public view returns(bool) {
    return ((block.number.sub(lastMintBlock)) > mintDuration);
  }

  function mintingFinished() public view returns(bool) {
    return (mintCycle > mintCycleCap);
  }
}