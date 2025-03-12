pragma solidity 0.5.16;
import "openzeppelin-solidity-2.3.0/contracts/ownership/Ownable.sol";
import "./interfaces/IUniverse.sol";
import "./interfaces/IFarm.sol";

contract UniverseConfig is IUniverse, Ownable {
    address payable public refferral;
    IFarm public planetETH;
    address public hqBase;
    address public token;
    
    uint256 public universeShare;
    uint256 public planetETHShare;
    uint256 public hqBaseShare;
    
    constructor(
        address payable _refferral, 
        IFarm _planetETH,
        address _hqBase, 
        uint256 _universeShare,
        uint256 _planetETHShare,
        uint256 _hqBaseShare,
        address _token
    ) public {
        setParams(_refferral, _planetETH, _hqBase, _universeShare, _planetETHShare, _hqBaseShare, _token);
    }

    function setParams(
        address payable _refferral, 
        IFarm _planetETH,
        address _hqBase, 
        uint256 _universeShare,
        uint256 _planetETHShare,
        uint256 _hqBaseShare,
        address _token
    ) public onlyOwner {
        refferral = _refferral;
        planetETH = _planetETH;
        hqBase = _hqBase;
        universeShare = _universeShare;
        planetETHShare = _planetETHShare;
        hqBaseShare = _hqBaseShare;
        token = _token;
    }

    function depositETH() external payable {
        planetETH.depositETH.value(msg.value)();
    }

    function getHQBase() external view returns (address) {
        return hqBase;
    }

    function getUniverseShare() external view returns (uint256) {
        return universeShare;
    }

    function getPlanetETHShare() external view returns (uint256) {
        return planetETHShare;
    }

    function getHQBaseShare() external view returns (uint256) {
        return hqBaseShare;
    }

    function getRefferral() external view returns (address payable) {
        return refferral;
    }
}