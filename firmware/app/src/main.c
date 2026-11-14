/*
 * DOT Ferry Project - nRF9151 Feather firmware
 *
 * Starter app: prints a heartbeat over the USB serial console and
 * blinks the on-board LED (devicetree alias led0) if present.
 */

#include <zephyr/kernel.h>
#include <zephyr/drivers/gpio.h>
#include <zephyr/logging/log.h>

LOG_MODULE_REGISTER(app, LOG_LEVEL_INF);

#define BLINK_MS 1000

#if DT_NODE_HAS_STATUS(DT_ALIAS(led0), okay)
static const struct gpio_dt_spec led = GPIO_DT_SPEC_GET(DT_ALIAS(led0), gpios);
#define HAVE_LED 1
#else
#define HAVE_LED 0
#endif

int main(void)
{
	LOG_INF("DOT Ferry firmware starting on %s", CONFIG_BOARD);

#if HAVE_LED
	if (!gpio_is_ready_dt(&led) ||
	    gpio_pin_configure_dt(&led, GPIO_OUTPUT_INACTIVE) < 0) {
		LOG_ERR("LED init failed");
	}
#endif

	uint32_t count = 0;

	while (1) {
#if HAVE_LED
		gpio_pin_toggle_dt(&led);
#endif
		LOG_INF("heartbeat %u", count++);
		k_msleep(BLINK_MS);
	}

	return 0;
}
