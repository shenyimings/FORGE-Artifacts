// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;


interface ITestUpkeep
	{
	function step1() external;
	function step2() external;
	function step3() external;
	function step4() external;
	function step5( address receiver ) external;
	function step6() external;
	function step7() external;
	function step8() external;
	function step9() external;
	function step10( uint256 daoStartingSaltBalance ) external;
	function step11( uint256 timeSinceLastUpkeep ) external;
	function step12( bytes32[] memory poolIDs) external;
	function step13( uint256 timeSinceLastUpkeep ) external;
	function step14() external;
	function step15() external;
	function step16() external;
	}
