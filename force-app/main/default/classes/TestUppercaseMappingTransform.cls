@IsTest
public class TestUppercaseMappingTransform implements MappingTransform {
    public Object transform(MappingTransformContext context) {
        return context.sourceValue == null ? null : String.valueOf(context.sourceValue).toUpperCase();
    }
}
