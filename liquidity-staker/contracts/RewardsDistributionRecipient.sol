pragma solidity ^0.5.16;
//被stakerewards继承
contract RewardsDistributionRecipient {
    //奖励分配者：stakerewards构造方法传入 等于工厂地址
    address public rewardsDistribution;

    function notifyRewardAmount(uint256 reward) external;

    modifier onlyRewardsDistribution() {
        require(msg.sender == rewardsDistribution, "Caller is not RewardsDistribution contract");
        _;
    }
}