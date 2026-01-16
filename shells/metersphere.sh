#!/bin/sh
# MeterSphere 主服务启动脚本
# 设置环境变量
export JAVA_CLASSPATH=${JAVA_CLASSPATH:-/app:/opt/jmeter/lib/ext/*:/app/lib/*}
export JAVA_MAIN_CLASS=${JAVA_MAIN_CLASS:-io.metersphere.Application}

# 执行官方启动脚本
exec /deployments/run-java.sh
