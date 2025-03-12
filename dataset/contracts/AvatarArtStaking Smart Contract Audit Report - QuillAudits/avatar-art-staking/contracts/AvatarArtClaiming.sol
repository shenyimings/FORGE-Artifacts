// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IERC20{
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        this;
        return msg.data;
    }
    
    function _now() internal view returns(uint){
        return block.timestamp;
    }
}

abstract contract Ownable is Context {
    
    modifier onlyOwner{
        require(_msgSender() == _owner, "Forbidden");
        _;
    }
    
    address internal _owner;
    
    constructor(){
        _owner = _msgSender();
    }
    
    function getOwner() external virtual view returns(address){
        return _owner;
    }
    
    function setOwner(address newOwner) external  onlyOwner{
        require(_owner != newOwner, "New owner is current owner");
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnerChanged(oldOwner, _owner);
    }
    
    event OwnerChanged(address oldOwner, address newOwner);
}

contract AvatarArtClaiming is Ownable{
    address public bnuTokenAddress;
    
    //Mapping between program and reward times
    //Project => reward time
    mapping(uint256 => uint256) internal _programRewardTimes;
    
    //Mapping between program and reward amount
    //Program => reward
    mapping(uint256 => uint256) internal _programRewardAmounts;
    
    //Mapping between program and winners
    //Program => winners
    mapping(uint256 => address[]) internal _programWinners;
    
    //Mapping to check if user has claimed reward or not
    //Program => account => is claimed
    mapping(uint256 => mapping(address => bool)) internal _winnerClaimeds;
    
    constructor(){
        bnuTokenAddress = 0x4954e0062E0A7668A2FE3df924cD20E6440a7b77;
    }
    
    function addProgram(uint256 program, uint256 rewardAmount, uint256 rewardTime) external onlyOwner{
        require(rewardAmount > 0 && rewardTime > 0, "input is 0");
        _programRewardTimes[program] = rewardTime;
        _programRewardAmounts[program] = rewardAmount;
    }
    
    function addWinner(uint256 program, address winner) external onlyOwner{
        require(!_isWinner(program, winner), "Winner existed");
        _programWinners[program].push(winner);
    }
    
    function claim(uint256 program) external{
        require(_isWinner(program, _msgSender()), "Be not winner");
        require(!_isClaimed(program, _msgSender()), "Claimed");
        uint256 rewardTime = _getProgramRewardTime(program);
        require(rewardTime > 0 && rewardTime <= _now(), "Claiming time does not start");
        
        IERC20(bnuTokenAddress).transfer(_msgSender(), _getProgramRewardAmount(program));
        _winnerClaimeds[program][_msgSender()] = true;
    }
    
    function getProgramRewardTime(uint256 program) external view returns(uint256){
        return _getProgramRewardTime(program);
    }
    
    function getProgramRewardAmount(uint256 program) external view returns(uint256){
        return _getProgramRewardAmount(program);
    }
    
    function getProgramWinners(uint256 program) external view returns(address[] memory){
        return _getProgramWinners(program);
    }
    
    function isClaimed(uint256 program, address account) external view returns(bool){
        return _winnerClaimeds[program][account];
    }
    
    function isWinner(uint256 program, address account) external view returns(bool){
        return _isWinner(program, account);
    }
    
    function setBnuTokenAddress(address newAddress) external onlyOwner{
         require(newAddress != address(0), "Zero address");
         bnuTokenAddress = newAddress;
    }
    
    function setProgramRewardAmount(uint256 program, uint256 rewardAmount) external onlyOwner{
         require(rewardAmount > 0, "input is 0");
        _programRewardAmounts[program] = rewardAmount;
    }
    
    function setProgramRewardTime(uint256 program, uint256 time) external onlyOwner{
        require(time > 0, "input is 0");
        _programRewardTimes[program] = time;
    }
    
    function withdrawToken(address token) external onlyOwner{
        IERC20 tokenContract = IERC20(token);
        if(tokenContract.balanceOf(address(this)) > 0)
            tokenContract.transfer(_msgSender(), tokenContract.balanceOf(address(this)));
    }
    
    function _getProgramRewardTime(uint256 program) internal view returns(uint256){
        return _programRewardTimes[program];
    }
    
    function _getProgramRewardAmount(uint256 program) internal view returns(uint256){
        return _programRewardAmounts[program];
    }
    
    function _getProgramWinners(uint256 program) internal view returns(address[] memory){
        return _programWinners[program];
    }
    
    function _isClaimed(uint256 program, address account) internal view returns(bool){
        return _winnerClaimeds[program][account];
    }
    
    function _isWinner(uint256 program, address account) internal view returns(bool){
        address[] memory winners = _getProgramWinners(program);
        if(winners.length == 0)
            return false;
            
        for(uint index = 0; index < winners.length; index++){
            if(winners[index] == account)
                return true;
        }
            
        return false;
    }
}