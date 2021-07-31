const TreasuryVester = artifacts.require("TreasuryVester");
const LiquidityPoolManager = artifacts.require("LiquidityPoolManager");

module.exports = function (deployer) {
  const YAY = '0x15957be9802B50c6D66f58a99A2a3d73F5aaf615'; // at mainnet.
  // const YAY = '0xEbD7fF328bC30087720e427CB8f11E9Bd8aF7d8A'; // at fuji.
  const WAVAX = '0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7'; // at mainnet.
  // const WAVAX = '0xd00ae08403B9bbb9124bB305C09058E32C39A48c'; // at fuji
  deployer.deploy(TreasuryVester, YAY).then(
    () => {
      return deployer.deploy(LiquidityPoolManager, WAVAX, YAY, TreasuryVester.address);
    }
  );
};