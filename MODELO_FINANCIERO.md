# Modelo financiero de Mi Presupuesto

## Por qué existe este documento

Este documento captura una decisión de modelo que tomé el 15 de junio de 2026, en la primera semana usando la app con mis datos reales.

Al cargar mis deudas y empezar a pagar cuotas, noté que la app trataba un pago de cuota igual que cualquier otro gasto. El ratio de gasto operativo se inflaba, las recomendaciones se calculaban sobre un excedente irreal, y la pantalla de Deudas mostraba números que no se conectaban con los movimientos de gasto. La fricción no era estética: era una confusión de fondo sobre **qué es un gasto**.

Después de pensarlo, llegué a una distinción que la app no estaba haciendo y que sí hacen los sistemas contables serios: pagar una cuota no es lo mismo que comprar comida. Las dos cosas afectan mi liquidez (sale plata real del bolsillo), pero significan cosas distintas. Una es consumo. La otra es reducción de un pasivo.

Este documento fija esa distinción como contrato para todo el código que venga después. Sirve como guía cuando vuelva a tocar el motor, cuando rediseñe pantallas, y como referencia pública del criterio detrás del proyecto.

## Conceptos

### Ingreso
Plata que entra. Salario, ventas, devoluciones, intereses ganados. Sin matices en v1.

### Gasto operativo
Plata que sale por consumo. Comida, transporte, ocio, servicios, salud, vivienda, educación, suscripciones. Se va y no vuelve. Es el verdadero "gasto" para el análisis de hábitos, el cálculo de fugas, el ratio de ahorro y la mayoría de los insights del motor.

### Amortización de deuda
Plata que sale para **reducir el saldo de una deuda existente**. Toca la liquidez igual que un gasto operativo, pero no es consumo: una parte (o el total, según el caso) vuelve a mi patrimonio como reducción de un pasivo. Por eso no se mezcla con los gastos operativos en los análisis.

Una cuota mensual típica es, en su mayoría, amortización. Puede tener un componente de intereses, que conceptualmente es consumo financiero. La separación de capital vs intereses dentro de una cuota es un nivel de detalle que dejo afuera de v1 (ver "Decisiones que dejo afuera de v1").

## Regla operativa

Un movimiento se clasifica como **amortización** si y solo si tiene `deuda_id` apuntando a una deuda activa. Si no, es un **gasto operativo**.

Sin excepciones, sin casos especiales, sin heurísticas adicionales. La clasificación depende exclusivamente del vínculo explícito que el usuario haya declarado al registrar el movimiento.

Esto significa que el switch "Gasto fijo" del formulario, por sí solo, no determina la naturaleza del movimiento: solo el `deuda_id` lo hace. El switch "Gasto fijo" sigue existiendo y marca que un gasto se repite cada mes, pero esa es una característica ortogonal a si el movimiento es operativo o amortización.

## Qué pasa cuando se rompe el vínculo

Si edito un movimiento que tenía deuda vinculada y le saco el switch "Gasto fijo" o le quito explícitamente la deuda, el movimiento pierde su razón de ser dentro del modelo: existía para representar una reducción de una deuda específica.

En ese caso la app **elimina el movimiento** y **devuelve el saldo a la deuda**, pero **avisa antes**: muestra un diálogo de confirmación con el texto "Esto va a eliminar el movimiento y devolver el saldo a la deuda. ¿Confirmás?". Si el usuario confirma, se ejecuta. Si cancela, no pasa nada.

La razón de eliminarlo en lugar de convertirlo en gasto operativo: si lo mantuviera como gasto suelto, estaría inflando los gastos del mes con plata que conceptualmente nunca fue consumo. El movimiento perdió su significado original y mantenerlo distorsiona los reportes.

La razón de avisar y no hacerlo en silencio: es una operación destructiva (se borra un registro), y el saldo de la deuda cambia visiblemente. El usuario debe entender qué va a pasar antes de que pase.

## Cómo se refleja en cada parte de la app

**Cascada de razonamiento.** La línea "Pago mis cuotas" suma exclusivamente las amortizaciones del mes (movimientos con `deuda_id` no nulo). La línea "Como y me muevo" suma solo gastos operativos de Alimentación y Transporte. El resto de la cascada no cambia.

**Score, ratios y fugas.** Todos los indicadores que miden hábitos de consumo se calculan únicamente sobre gastos operativos. Las amortizaciones no entran en el numerador del ratio de gasto, no aparecen como fugas de dinero, y no afectan el score financiero del lado de los gastos. Sí afectan, indirectamente, el disponible del mes: amortizar deuda reduce la plata disponible para invertir o ahorrar, lo cual ya está reflejado en la cascada.

**Resumen de la home.** Las columnas "Ingresos", "Gastos" y "Deudas" del resumen mantienen el comportamiento actual: "Gastos" muestra gastos operativos, "Deudas" muestra amortizaciones. La separación visual ya existía; ahora también es conceptual.

**Saldo de cada deuda.** El saldo actual de una deuda se calcula como `saldo_inicial − suma de amortizaciones vinculadas`. No se guarda como dato fijo. Si se borra una amortización, el saldo se recompone solo. Si se borra la deuda, las amortizaciones quedan con `deuda_id = NULL` y pasan a ser gastos operativos (es una operación distinta a "romper el vínculo" porque la voluntad del usuario es distinta: eliminar la deuda, no editar un movimiento).

**Pantalla de Deudas.** Cada deuda muestra el saldo calculado y un historial de pagos: la lista de movimientos vinculados, ordenados por fecha. Este rediseño es trabajo posterior y se encara cuando el modelo esté cableado en el motor.

## Decisiones que dejo afuera de v1

Cosas que tienen sentido dentro del mismo marco pero que decidí no atacar todavía, para que quede explícito que no son olvidos:

**Separar capital e intereses dentro de una cuota.** Conceptualmente, parte de una cuota mensual es amortización y parte es interés. En v1 se cuenta toda la cuota como amortización: el saldo de la deuda baja por el monto total pagado. Esto sobreestima la velocidad de reducción real cuando hay intereses altos. Es un trade-off consciente: implementarlo bien requiere conocer la tasa de cada deuda y aplicar fórmulas de amortización, y prefiero validar el modelo simple antes.

**Sugerencias automáticas de pago.** La app no propone movimientos de cuota cada mes. El usuario los registra cuando los hace. La automatización tiene sentido cuando haya historial suficiente para que la sugerencia sea confiable (probablemente en la Etapa 2 del proyecto, donde los algoritmos clásicos detectan patrones de pago).

**Aportes a metas y a fondo de emergencia como "amortizaciones inversas".** Conceptualmente, transferir plata a una meta o a un fondo es análogo a amortizar: sale liquidez, pero no es consumo, va a otra parte de mi patrimonio. Aplicar la misma regla sería coherente, pero requiere un modelo de cuentas/destinos que todavía no tengo. Por ahora los aportes se cuentan dentro del flujo del mes sin distinción especial.

## Glosario

**`deuda_id`**: columna en la tabla `movimientos`. Si tiene valor, el movimiento es una amortización vinculada a esa deuda. Si es nulo, el movimiento es un gasto operativo o un ingreso normal.

**Amortización**: movimiento de salida de plata cuyo destino es reducir una deuda concreta. No es consumo.

**Gasto operativo**: movimiento de salida de plata por consumo. Incluye gastos fijos (arriendo, servicios) y variables (comida, ocio).

**Saldo calculado**: el saldo actual de una deuda no se guarda; se computa restando del saldo inicial todas las amortizaciones vinculadas. Esto garantiza que el saldo nunca quede inconsistente con los movimientos.

---

Documento vivo. Las decisiones acá fijadas se modifican en commits explícitos cuando el modelo evolucione, no por suposiciones implícitas en el código.
