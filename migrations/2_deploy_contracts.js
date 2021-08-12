const TreasuryVester = artifacts.require("TreasuryVester");
const LiquidityPoolManager = artifacts.require("LiquidityPoolManager");
const YAY = '0xEbD7fF328bC30087720e427CB8f11E9Bd8aF7d8A';

module.exports = function (deployer) {
  deployer.deploy(TreasuryVester, YAY).then(
    () => {
      const WAVAX = '0xd00ae08403B9bbb9124bB305C09058E32C39A48c';
      return deployer.deploy(LiquidityPoolManager, WAVAX, YAY, TreasuryVester.address)
    }
  );
};
